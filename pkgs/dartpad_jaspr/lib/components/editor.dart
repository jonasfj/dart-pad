import 'dart:async';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

@JS('Editor.createEditor')
external _EditorHandle _createEditor();

@JS()
extension type _EditorHandle._(JSObject _) implements JSObject {
  /// Switches the active file.
  /// Note on URIs: Paths within the dartpad workspace MUST be relative (e.g. `lib/main.dart`).
  /// Paths outside the workspace (e.g. pub cache) MUST be absolute URIs (`file:///...`).
  external void switchFile(JSString uri, [JSString? content]);
  external void closeFile(JSString uri);
  external JSString? getFileContent(JSString uri);
  external _LanguageServerHandle? connectLanguageServer(_LSPCallbacks callbacks, String workspaceFolderUri);
  external void format();
  external set onRun(JSFunction? callback);
  external set onSave(JSFunction? callback);
  external web.HTMLElement get editorContainer;
}

@JS()
@anonymous
extension type _LSPCallbacks._(JSObject _) implements JSObject {
  external factory _LSPCallbacks({
    required JSFunction sendLanguageServerMessage,
    required JSFunction onLanguageServerDisconnected,
    required JSFunction onDisplayFileRequested,
    required JSFunction onRequestFile,
    required JSFunction onLanguageServerProgress,
  });
}

@JS()
extension type _LanguageServerHandle._(JSObject _) implements JSObject {
  external void deliverLanguageServerMessage(JSString json);
  external void disconnect();
}

/// A handle to interact with the connected language server.
final class LanguageServerHandle {
  final _LanguageServerHandle _handle;
  LanguageServerHandle._(this._handle);

  /// Delivers a JSON RPC message from the language server to CodeMirror.
  void deliverLanguageServerMessage(String json) {
    _handle.deliverLanguageServerMessage(json.toJS);
  }

  /// Disconnects the language server from the editor.
  void disconnect() {
    _handle.disconnect();
  }
}

/// The public controller to imperatively command the editor.
final class EditorController {
  _EditorHandle? _handle;

  EditorController() {
    if (kIsWeb) {
      _handle = _createEditor();
    }
  }

  web.HTMLElement? get _editorContainer => _handle?.editorContainer;

  /// Switches the editor to display the given file [uri].
  /// Optionally provides new [content].
  void switchFile(String uri, {String? content}) {
    _handle?.switchFile(uri.toJS, content?.toJS);
  }

  /// Closes the file [uri] in the editor, removing it from background state.
  void closeFile(String uri) {
    _handle?.closeFile(uri.toJS);
  }

  /// Gets the current text content of the file [uri] from the editor.
  String? getFileContent(String uri) {
    return _handle?.getFileContent(uri.toJS)?.toDart;
  }

  /// Formats the currently active document using the language server.
  void format() {
    _handle?.format();
  }

  /// Connects the language server and returns a handle for message piping.
  /// Throws a [StateError] if the editor is not initialized or if a server is already connected.
  LanguageServerHandle connectLanguageServer({
    required void Function(String) sendLanguageServerMessage,
    required void Function() onLanguageServerDisconnected,
    required Future<void> Function(String) onDisplayFileRequested,
    required Future<String?> Function(String) onRequestFile,
    required void Function(String token, String kind, String title) onLanguageServerProgress,
    required Uri workspaceFolderUri,
  }) {
    if (_handle == null) throw StateError('Editor not initialized');

    final lspHandle = _handle!.connectLanguageServer(
      _LSPCallbacks(
        sendLanguageServerMessage: sendLanguageServerMessage.toJS,
        onLanguageServerDisconnected: onLanguageServerDisconnected.toJS,
        onDisplayFileRequested: ((JSString uri) {
          return onDisplayFileRequested(uri.toDart).then((_) => null).toJS;
        }).toJS,
        onRequestFile: ((JSString uri) {
          return onRequestFile(uri.toDart).then((content) => content?.toJS).toJS;
        }).toJS,
        onLanguageServerProgress: ((JSString token, JSString kind, JSString title) {
          onLanguageServerProgress(token.toDart, kind.toDart, title.toDart);
        }).toJS,
      ),
      workspaceFolderUri.toString(),
    );

    if (lspHandle == null) {
      throw StateError('Language server already connected');
    }
    return LanguageServerHandle._(lspHandle);
  }
}

final class Editor extends StatefulComponent {
  final EditorController controller;
  final void Function()? onRun;
  final void Function()? onSave;

  const Editor({
    required this.controller,
    this.onRun,
    this.onSave,
    super.key,
  });

  @override
  State<Editor> createState() => _EditorState();

  @css
  static List<StyleRule> get styles => [
    css('.cm-tooltip', [
      css('&').styles(
        raw: {
          'background-color': '#0d1117 !important',
          'border': '1px solid #30363d !important',
          'border-radius': '6px !important',
          'box-shadow': '0 8px 24px rgba(1, 4, 9, 0.85) !important',
          'color': '#c9d1d9 !important',
          'z-index': '200 !important',
        },
      ),
      css('&.cm-tooltip-hover, & .cm-completionInfo').styles(
        fontFamily: const FontFamily.list([
          FontFamily('Google Sans Text'),
          FontFamily('ui-sans-serif'),
          FontFamilies.sansSerif,
        ]),
        fontSize: 14.px,
        lineHeight: 1.5.em,
        raw: {
          'max-width': '700px !important',
          'max-height': 'calc(80vh - 40px) !important',
          'overflow-y': 'auto !important',
          'padding': '12px 16px !important',
        },
      ),
      css('h1, h2, h3').styles(
        padding: Padding.only(bottom: 0.3.em),
        margin: Margin.only(top: 16.px, bottom: 8.px),
        border: Border.only(
          bottom: BorderSide.solid(color: Color('#21262d'), width: 1.px),
        ),
        color: Color('#e6edf3'),
        fontSize: 14.px,
        fontWeight: FontWeight.w600,
      ),
      css('h1:first-child').styles(
        margin: Margin.only(top: 0.px),
      ),
      css('p').styles(
        margin: Margin.only(bottom: 12.px),
      ),
      css('p:last-child').styles(
        margin: Margin.only(bottom: 0.px),
      ),
      css('a').styles(
        color: Color('#58a6ff'),
        textDecoration: const TextDecoration(line: TextDecorationLine.none),
      ),
      css('a:hover').styles(
        textDecoration: const TextDecoration(line: TextDecorationLine.underline),
      ),
      css('pre').styles(
        radius: BorderRadius.all(Radius.circular(6.px)),
        overflow: Overflow.auto,
        color: Color('#e6edf3'),
        fontFamily: const FontFamily.list([FontFamily('Google Sans Mono'), FontFamilies.monospace]),
        fontSize: 12.px,
        lineHeight: 1.5.em,
        raw: {
          'background-color': '#161b22 !important',
          'border': '1px solid #30363d !important',
          'padding': '12px !important',
          'margin': '12px 0 !important',
        },
      ),
      css('pre code').styles(
        raw: {
          'background-color': 'transparent !important',
          'padding': '0 !important',
          'border-radius': '0 !important',
          'font-family': 'inherit !important',
          'font-size': 'inherit !important',
          'color': 'inherit !important',
        },
      ),
      css(':not(pre) > code').styles(
        radius: BorderRadius.all(Radius.circular(6.px)),
        color: Color('#c9d1d9'),
        fontFamily: const FontFamily.list([FontFamily('Google Sans Mono'), FontFamilies.monospace]),
        fontSize: 85.percent,
        raw: {
          'background-color': 'rgba(110, 118, 129, 0.4) !important',
          'padding': '0.2em 0.4em !important',
        },
      ),
      css('ul, ol').styles(
        padding: Padding.only(left: 24.px),
        margin: Margin.only(bottom: 12.px),
      ),
      css('::-webkit-scrollbar').styles(
        width: 8.px,
        height: 8.px,
      ),
      css('::-webkit-scrollbar-thumb').styles(
        radius: BorderRadius.all(Radius.circular(4.px)),
        backgroundColor: Color('#30363d'),
      ),
      css('::-webkit-scrollbar-track').styles(
        backgroundColor: Colors.transparent,
      ),
    ]),
    css('.cm-tooltip-autocomplete > ul > li').styles(
      raw: {
        'padding': '6px 12px !important',
        'font-family': '\'Google Sans Mono\', monospace !important',
      },
      fontSize: 13.px,
      border: Border.only(
        left: BorderSide.solid(color: Colors.transparent, width: 2.px),
      ),
    ),
    css('.cm-tooltip-autocomplete > ul > li[aria-selected]').styles(
      border: Border.only(
        left: BorderSide.solid(color: Color('#ffffff'), width: 2.px),
      ),
      raw: {
        'background-color': '#1f6feb !important',
        'color': '#ffffff !important',
      },
    ),
  ];
}

final class _EditorState extends State<Editor> {
  final GlobalNodeKey<web.HTMLDivElement> _containerKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final handle = component.controller._handle;
      if (handle != null) {
        handle.onRun = (() => component.onRun?.call()).toJS;
        handle.onSave = (() => component.onSave?.call()).toJS;
      }

      // Defer DOM attachment until the node is rendered
      web.window.requestAnimationFrame(
        (num _) {
          final node = _containerKey.currentNode;
          if (node != null && component.controller._editorContainer != null) {
            node.appendChild(component.controller._editorContainer!);
          }
        }.toJS,
      );
    }
  }

  @override
  void didUpdateComponent(covariant Editor oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (kIsWeb) {
      if (oldComponent.controller != component.controller) {
        final parentNode = _containerKey.currentNode;
        final oldNode = oldComponent.controller._editorContainer;
        final newNode = component.controller._editorContainer;

        if (parentNode != null) {
          if (oldNode != null && oldNode.parentNode == parentNode) {
            parentNode.removeChild(oldNode);
          }
          if (newNode != null) {
            parentNode.appendChild(newNode);
          }
        }

        final handle = component.controller._handle;
        if (handle != null) {
          handle.onRun = (() => component.onRun?.call()).toJS;
          handle.onSave = (() => component.onSave?.call()).toJS;
        }
      }
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      key: _containerKey,
      classes: 'editor-wrapper',
      styles: Styles(
        width: 100.percent,
        height: 100.percent,
        minHeight: 300.px,
      ),
      [],
    );
  }
}
