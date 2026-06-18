import 'dart:async';
import 'dart:typed_data';

// Stub types for package:dartpad so the app can be compiled on the Dart VM.

enum ConsoleLevel { log, info, warn, error }

class DartPad {
  static Future<DartPad> create({
    required Uri assetBaseUrl,
    Uri? pubHostedUrl,
    required Uri sdkLocation,
  }) async => throw UnsupportedError('DartPad is not supported on the VM');

  Future<void> dispose() async {}
  Future<Workspace> createWorkspace() async => throw UnsupportedError('');
}

class Workspace {
  int get id => throw UnsupportedError('');
  Uri get workspaceFolder => throw UnsupportedError('');

  Future<({String? code, List<String> compiledLibraryUris, String log})> compile(Uri uri) async => throw UnsupportedError('');
  Future<void> createFolder(String path) async {}
  Future<void> deleteFileSystemEntity(String path) async {}
  Future<void> dispose() async {}
  Future<Uint8List> exportTarArchive(String uri) async => throw UnsupportedError('');
  Future<bool> fileExist(String uri) async => false;
  Future<bool> folderExist(String uri) async => false;
  Future<void> importTarArchive(String uri, Uint8List archive) async {}
  Future<List<({String path, String type})>> listDirectory({bool ignoreHidden = false, bool recursive = false, required String uri}) async => [];
  Future<({String log})> pub({List<String> args = const [], required String command, String? uri}) async => throw UnsupportedError('');
  Future<Uint8List> readFileAsBytes(String uri) async => throw UnsupportedError('');
  Future<String> readFileAsText(String uri) async => '';
  Future<HotReloadCompiler> startHotReloadCompiler(Uri uri) async => throw UnsupportedError('');
  Future<LanguageServer> startLanguageServer() async => throw UnsupportedError('');
  Future<({int? size, String type})> stat(String uri) async => throw UnsupportedError('');
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {}
  Future<void> writeFileFromText(String uri, String text) async {}
}

class LanguageServer {
  int get id => throw UnsupportedError('');
  dynamic get languageServerChannel => throw UnsupportedError('');
  Workspace get workspace => throw UnsupportedError('');
  Future<void> stop() async {}
}

class Sandbox {
  static Future<Sandbox> createIFrame(dynamic container, {required Uri assetBaseUrl, String? bodyHtml, String? headHtml, required Uri sdkLocation}) async => throw UnsupportedError('');
  
  Stream<({ConsoleLevel level, String message})> get onConsole => const Stream.empty();
  
  Future<({int dartSize, int evaluatedModules, int jsSize, Duration loadTime, int sourceMapSize})> appMetrics() async => throw UnsupportedError('');
  void dispose() {}
  Future<({int generation})> getHotReloadGeneration() async => throw UnsupportedError('');
  Future<({int generation})> getHotRestartGeneration() async => throw UnsupportedError('');
  Future<({int generation})> hotReload({String? code, List<Uri>? librariesToReload, String? moduleName}) async => throw UnsupportedError('');
  Future<({int generation})> hotRestart({String? code, String? moduleName}) async => throw UnsupportedError('');
  Future<void> loadModule({required String code, String? moduleName}) async {}
  Future<void> runApp(Uri uri) async {}
  Future<void> runMain(Uri uri) async {}
}

class HotReloadCompiler {
  int get id => throw UnsupportedError('');
  Workspace get workspace => throw UnsupportedError('');
  Future<void> close() async {}
  Future<({String? code, List<String> compiledLibraryUris, String log})> compile() async => throw UnsupportedError('');
}
