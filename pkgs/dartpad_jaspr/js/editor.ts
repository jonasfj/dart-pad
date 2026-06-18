import { EditorView, basicSetup } from 'codemirror';
import { EditorState, Compartment, Extension, Prec } from '@codemirror/state';
import { LSPClient, languageServerExtensions, formatDocument } from '@codemirror/lsp-client';
import { EditorWorkspace, getLanguageIdFromUri } from './workspace';
import { vscodeKeymap } from '@replit/codemirror-vscode-keymap';
import { keymap } from '@codemirror/view';
import { oneDark } from '@codemirror/theme-one-dark';

import { yaml } from '@codemirror/lang-yaml';
import { json } from '@codemirror/lang-json';
import { markdown } from '@codemirror/lang-markdown';
import { javascript } from '@codemirror/lang-javascript';
import { dart } from './codemirror-lang-dart/index';

const languages: Record<string, () => Extension> = {
  yaml,
  json,
  markdown,
  javascript,
  dart
};

export interface EditorHandle {
  /**
   * Switches the active file. 
   * Note on URIs: Paths within the dartpad workspace MUST be relative (e.g. `lib/main.dart`).
   * Paths outside the workspace (e.g. pub cache) MUST be absolute URIs (`file:///...`).
   */
  switchFile(uri: string, content?: string | null): void;
  closeFile(uri: string): void;
  getFileContent(uri: string): string | null;
  connectLanguageServer(callbacks: LSPCallbacks, workspaceFolderUri: string): LanguageServerHandle | void;
  format(): void;
  onRun?: () => void;
  onSave?: () => void;
  readonly editorContainer: HTMLElement;
}

export interface LSPCallbacks {
  sendLanguageServerMessage: (json: string) => void;

  /**
   * Called when the Language Server requests to navigate to a file (e.g., Go to Definition).
   * The Dart side MUST update its UI to show the file as active, fetch the file content 
   * if it hasn't been loaded yet, and call `EditorHandle.switchFile(uri, content)`.
   * 
   * The `uri` will be relative if inside the workspace, and absolute if outside.
   */
  onDisplayFileRequested: (uri: string) => Promise<void>;

  /**
   * Called when the Language Server needs the content of a file that hasn't been opened yet 
   * (e.g., to show a preview snippet in the Find References panel).
   * The Dart side MUST return the full string content of the file.
   * 
   * The `uri` will be relative if inside the workspace, and absolute if outside.
   */
  onRequestFile: (uri: string) => Promise<string | null>;

  /**
   * Called when the Language Server transport is unsubscribed.
   * This is a signal that the LSP client is no longer listening to messages.
   */
  onLanguageServerDisconnected: () => void;
  onLanguageServerProgress: (token: string, kind: string, title: string) => void;
}

export interface LanguageServerHandle {
  deliverLanguageServerMessage: (json: string) => void;
  disconnect: () => void;
}

interface FileState {
  state: EditorState;
  lspCompartment: Compartment;
  languageId: string;
}

function resolveUri(uri: string, workspaceFolderUri: string | null): string {
  if (!workspaceFolderUri) return uri;
  if (uri.includes('://') || uri.startsWith('file:')) return uri;
  let base = workspaceFolderUri;
  if (!base.endsWith('/')) base += '/';
  return base + uri;
}

/**
 * Creates a new CodeMirror editor instance.
 * 
 * @returns The handle used by Dart to control the editor.
 */
export function createEditor(): EditorHandle {
  let view = new EditorView({});
  view.dom.style.width = '100%';
  view.dom.style.height = '100%';
  let lspClient: LSPClient | null = null;
  let workspace: EditorWorkspace | null = null;
  let workspaceFolderUri: string | null = null;
  let activeUri: string | null = null;
  let states: Record<string, FileState> = {};

  const handle: EditorHandle = {
    switchFile(uri: string, content?: string | null) {
      if (lspClient) lspClient.sync();

      let languageId = getLanguageIdFromUri(uri);

      if (!states[uri]) {
        let lspCompartment = new Compartment();
        let extensions: Extension[] = [
          basicSetup,
          oneDark,
          keymap.of(vscodeKeymap as any),
          Prec.highest(keymap.of([
            { key: "Mod-Enter", run: () => { if (handle.onRun) handle.onRun(); return true; }, preventDefault: true },
            { key: "Mod-s", run: () => { if (handle.onSave) handle.onSave(); return true; }, preventDefault: true }
          ])),
        ];

        let languageFactory = languages[languageId];
        if (languageFactory) extensions.push(languageFactory());

        extensions.push(lspCompartment.of(lspClient ? lspClient.plugin(resolveUri(uri, workspaceFolderUri), languageId) : []));

        let state = EditorState.create({
          doc: content || "",
          extensions: extensions
        });

        states[uri] = { state, lspCompartment, languageId };
      } else if (content !== null && content !== undefined) {
        if (states[uri].state.doc.toString() !== content) {
          states[uri].state = states[uri].state.update({
            changes: { from: 0, to: states[uri].state.doc.length, insert: content }
          }).state;
        }
      }

      activeUri = uri;
      view.setState(states[uri].state);
    },

    closeFile(uri: string) {
      if (workspace) {
        workspace.forceCloseFile(uri);
      }
      delete states[uri];
      if (activeUri === uri) {
        activeUri = null;
      }
    },

    getFileContent(uri: string): string | null {
      if (states[uri]) {
        return states[uri].state.doc.toString();
      }
      return null;
    },

    format() {
      formatDocument(view);
    },

    connectLanguageServer({ sendLanguageServerMessage, onDisplayFileRequested, onRequestFile, onLanguageServerDisconnected, onLanguageServerProgress }: LSPCallbacks, folderUri: string): LanguageServerHandle | void {
      if (lspClient) return;

      workspaceFolderUri = folderUri;

      let deliverLanguageServerMessage: ((json: string) => void) | null = null;

      const transport = {
        send: sendLanguageServerMessage,
        subscribe: (handler: (value: string) => void) => {
          deliverLanguageServerMessage = (json: string) => {
            try {
              const message = JSON.parse(json);
              if (message.method === 'window/workDoneProgress/create') {
                sendLanguageServerMessage(JSON.stringify({
                  jsonrpc: "2.0",
                  id: message.id,
                  result: null
                }));
                return;
              }
              if (message.method === '$/progress') {
                const token = String(message.params?.token);
                const value = message.params?.value;
                if (value?.kind === 'begin') {
                  onLanguageServerProgress(token, 'begin', value.title || '');
                } else if (value?.kind === 'report') {
                  onLanguageServerProgress(token, 'report', value.message || '');
                } else if (value?.kind === 'end') {
                  onLanguageServerProgress(token, 'end', value.message || '');
                }
                return;
              }
            } catch (e) {
              // Ignore parse errors, let client handle them
            }
            handler(json);
          };
        },
        unsubscribe: () => {
          deliverLanguageServerMessage = null;
          onLanguageServerDisconnected();
        }
      };

      lspClient = new LSPClient({
        extensions: [
          {
            clientCapabilities: { window: { workDoneProgress: true } }
          },
          ...languageServerExtensions()
        ],
        workspace: (client) => {
          workspace = new EditorWorkspace(client, {
            sendLanguageServerMessage,
            onDisplayFileRequested,
            onRequestFile,
            onLanguageServerDisconnected,
            onLanguageServerProgress,
          });
          return workspace;
        }
      });

      lspClient.connect(transport);

      for (let uri in states) {
        let { state, lspCompartment, languageId } = states[uri];
        states[uri].state = state.update({
          effects: lspCompartment.reconfigure(lspClient.plugin(resolveUri(uri, workspaceFolderUri), languageId))
        }).state;
      }

      if (activeUri && states[activeUri]) {
        view.setState(states[activeUri].state);
      }

      return {
        deliverLanguageServerMessage(json: string) {
          if (deliverLanguageServerMessage) deliverLanguageServerMessage(json);
        },
        disconnect() {
          if (lspClient) {
            lspClient.disconnect();
            lspClient = null;
            workspace = null;
            workspaceFolderUri = null;

            for (let uri in states) {
              let { state, lspCompartment } = states[uri];
              states[uri].state = state.update({
                effects: lspCompartment.reconfigure([])
              }).state;
            }

            if (activeUri && states[activeUri]) {
              view.setState(states[activeUri].state);
            }
          }
        }
      };
    },

    get editorContainer(): HTMLElement {
      return view.dom;
    }
  };

  return handle;
}
