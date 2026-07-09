import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('Editor.createEditor')
external _EditorHandle _createEditor();

@JS()
extension type _EditorHandle._(JSObject _) implements JSObject {
  external void switchFile(JSString uri, [JSString? content]);
  external void closeFile(JSString uri);
  external JSString? getFileContent(JSString uri);
  external _LanguageServerHandle? connectLanguageServer(
    _LSPCallbacks callbacks,
    String workspaceFolderUri,
  );
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

final class LanguageServerHandle {
  final _LanguageServerHandle _handle;
  LanguageServerHandle._(this._handle);

  void deliverLanguageServerMessage(String json) {
    _handle.deliverLanguageServerMessage(json.toJS);
  }

  void disconnect() {
    _handle.disconnect();
  }
}

final class EditorController {
  _EditorHandle? _handle;

  EditorController() {
    _handle = _createEditor();
  }

  web.HTMLElement? get editorContainer => _handle?.editorContainer;

  void switchFile(String uri, {String? content}) {
    _handle?.switchFile(uri.toJS, content?.toJS);
  }

  void closeFile(String uri) {
    _handle?.closeFile(uri.toJS);
  }

  String? getFileContent(String uri) {
    return _handle?.getFileContent(uri.toJS)?.toDart;
  }

  void format() {
    _handle?.format();
  }

  set onRun(void Function() callback) {
    _handle?.onRun = callback.toJS;
  }

  set onSave(void Function() callback) {
    _handle?.onSave = callback.toJS;
  }

  LanguageServerHandle connectLanguageServer({
    required void Function(String) sendLanguageServerMessage,
    required void Function() onLanguageServerDisconnected,
    required Future<void> Function(String) onDisplayFileRequested,
    required Future<String?> Function(String) onRequestFile,
    required void Function(String token, String kind, String title)
    onLanguageServerProgress,
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
          return onRequestFile(uri.toDart)
              .then((content) => content?.toJS)
              .toJS;
        }).toJS,
        onLanguageServerProgress:
            ((JSString token, JSString kind, JSString title) {
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
