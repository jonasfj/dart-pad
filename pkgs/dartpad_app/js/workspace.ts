import { EditorView } from 'codemirror';
import { Text } from '@codemirror/state';
import { LSPClient, Workspace, LSPPlugin, WorkspaceFile } from '@codemirror/lsp-client';
import type { LSPCallbacks } from './editor';

export function getLanguageIdFromUri(uri: string): string {
  const ext = uri.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'dart': return 'dart';
    case 'yaml': case 'yml': return 'yaml';
    case 'json': return 'json';
    case 'md': case 'markdown': return 'markdown';
    case 'js': return 'javascript';
    default: return '';
  }
}

export class EditorWorkspaceFile implements WorkspaceFile {
  constructor(
    public uri: string,
    public languageId: string,
    public version: number,
    public doc: Text,
    public view: EditorView | null
  ) { }
  getView(): EditorView | null { return this.view; }
}

export class EditorWorkspace extends Workspace {
  files: EditorWorkspaceFile[] = [];
  fileVersions: { [uri: string]: number } = {};

  constructor(client: LSPClient, private callbacks: LSPCallbacks) {
    super(client);
  }

  nextFileVersion(uri: string): number {
    this.fileVersions[uri] = (this.fileVersions[uri] ?? -1) + 1;
    return this.fileVersions[uri];
  }

  syncFiles() {
    let result = [];
    for (let file of this.files) {
      if (!file.view) continue;
      let plugin = LSPPlugin.get(file.view);
      if (!plugin) continue;

      let changes = plugin.unsyncedChanges;
      if (!changes.empty) {
        result.push({ changes, file, prevDoc: file.doc });
        file.doc = file.view.state.doc;
        file.version = this.nextFileVersion(file.uri);
        plugin.clear();
      }
    }
    return result;
  }

  openFile(uri: string, languageId: string, view: EditorView) {
    let file = this.getFile(uri) as EditorWorkspaceFile | null;
    if (!file) {
      file = new EditorWorkspaceFile(uri, languageId, this.nextFileVersion(uri), view.state.doc, view);
      this.files.push(file);
      this.client.didOpen(file);
    } else {
      file.view = view;
      file.doc = view.state.doc;
      if (!file.languageId) {
        file.languageId = languageId;
        this.client.didOpen(file);
      }
    }
  }

  closeFile(uri: string, view: EditorView) {
    let file = this.getFile(uri) as EditorWorkspaceFile | null;
    if (file && file.view === view) {
      file.view = null;
    }
  }

  forceCloseFile(uri: string) {
    let file = this.getFile(uri) as EditorWorkspaceFile | null;
    if (file) {
      this.files = this.files.filter(f => f !== file);
      this.client.didClose(uri);
    }
  }

  requestFile(uri: string): Promise<WorkspaceFile | null> {
    let file = this.getFile(uri);
    if (file) return Promise.resolve(file);

    return this.callbacks.onRequestFile(uri).then(content => {
      if (content === null || content === undefined) return null;
      let newFile = new EditorWorkspaceFile(uri, getLanguageIdFromUri(uri), this.nextFileVersion(uri), Text.of(content.split("\n")), null);
      this.files.push(newFile);
      this.client.didOpen(newFile);
      return newFile;
    });
  }

  async displayFile(uri: string): Promise<EditorView | null> {
    // Ask Dart to display this file. Dart MUST update its tree-view,
    // fetch the content if needed, and call handle.switchFile().
    await this.callbacks.onDisplayFileRequested(uri);
    let file = this.getFile(uri) as EditorWorkspaceFile | null;
    return file ? file.getView() : null;
  }
}
