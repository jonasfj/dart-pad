import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_web/web.dart';

import 'src/dartpad/dartpad.dart';
import 'src/load_example.dart';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/editor.dart';
import 'components/file_tree.dart';
import 'components/sandbox.dart';
import 'components/split_pane.dart';
import 'components/panel.dart';
import 'components/console.dart';
import 'components/app_header.dart';
import 'components/editor_toolbar.dart';
import 'components/modal.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import 'components/icon_button.dart';
import 'constants/theme.dart';
import 'providers/task_provider.dart';

@client
final class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();
}

class ModalState {
  final String title;
  final String contentText;
  final String? inputPlaceholder;
  final String confirmText;
  final bool showInput;
  final String? initialValue;
  final void Function(String?) onConfirm;
  final void Function() onCancel;

  ModalState({
    required this.title,
    required this.contentText,
    this.inputPlaceholder,
    required this.confirmText,
    this.showInput = false,
    this.initialValue,
    required this.onConfirm,
    required this.onCancel,
  });
}

final class AppState extends State<App> {
  ModalState? _modalState;

  final EditorController _editorController = EditorController();

  /// Initial files, available once example has been loaded, unavailable when
  /// [_workspace] has been loaded, because then [_workspace] is the source of
  /// truth.
  Map<String, Uint8List>? _initialFiles;

  String? _activeFile;

  /// The DartPad worker, available when worker has loaded
  // ignore: unused_field
  DartPad? _dartPad;
  // ignore: unused_field
  Sandbox? _sandbox;

  /// The DartPad worker workspace where files live, available when
  /// _initialFiles have been written to in-memory file-system.
  Workspace? _workspace;
  LanguageServer? _languageServer;
  LanguageServerHandle? _lsHandle;
  HotReloadCompiler? _compiler;
  String? _lastCompilerFile;

  void _onLspProgress(String token, String kind, String title) {
    final id = 'lsp_$token';
    final notifier = context.read(appTasksProvider.notifier);
    if (kind == 'begin') {
      notifier.startTask(id, title, expiration: const Duration(seconds: 60));
    } else if (kind == 'report' && title.isNotEmpty) {
      notifier.updateTask(id, title);
    } else if (kind == 'end') {
      notifier.endTask(id);
    }
  }

  final StreamController<String> _consoleStreamController = StreamController<String>.broadcast();

  List<String> _files = [];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initStateWeb();
    }
  }

  Future<void> _initStateWeb() async {
    final uri = Uri.parse(window.location.href);
    final package = uri.queryParameters['package'] ?? 'retry';
    final version = uri.queryParameters['version'];
    final path = uri.queryParameters['path'] ?? '/';

    // Start creating the DartPad workspace concurrently
    final workspaceReady = Future.microtask(() async {
      final dartPad = _dartPad = await DartPad.create(
        assetBaseUrl: Uri.base.resolve('/asset/worker/'),
        sdkLocation: Uri.parse('dart/'),
      );

      return await dartPad.createWorkspace();
    });

    // Start downloading the example code concurrently
    final exampleReady = Future.microtask(() async {
      final files = _initialFiles = await loadExample(package: package, version: version, path: path);
      if (files.isEmpty) {
        files['main.dart'] = Uint8List.fromList([]);
      }

      final activeFile = [
        'bin/example.dart',
        'example.dart',
        'bin/main.dart',
        'main.dart',
        'lib/main.dart',
        'lib/example.dart',
        ?files.keys.where((f) => f.endsWith('.dart')).firstOrNull,
        ?files.keys.where((f) => f.endsWith('.md')).firstOrNull,
        ?files.keys.firstOrNull,
      ].firstWhere((f) => files.keys.contains(f));

      setState(() {
        _files = files.keys.toList();
        // Update the FileTree
        _activeFile = activeFile;
      });
      _editorController.switchFile(activeFile, content: utf8.decode(files[activeFile]!, allowMalformed: true));
    });

    // TODO: On failure we display a big banner!
    final workspace = await workspaceReady;
    await exampleReady;

    // Write initial contents to the workspace
    for (final entry in _initialFiles!.entries) {
      await workspace.writeFileFromBytes(entry.key, entry.value);
    }
    _workspace = workspace;
    _initialFiles = null; // workspace is now the source of truth

    final hasPubspec = await workspace.fileExist('pubspec.yaml');
    if (hasPubspec) {
      await context.runTask('pub_get', 'Running pub get', () async {
        _consoleStreamController.add('[SYSTEM] Running pub get');
        try {
          final pubResult = await workspace.pub(command: 'get');
          _consoleStreamController.add(pubResult.log);
        } catch (e) {
          _consoleStreamController.add('[ERROR] pub get failed: $e');
        }
      }, expiration: const Duration(seconds: 60));
    }

    final languageServer = _languageServer = await workspace.startLanguageServer();

    StreamSubscription? lsSubscription;
    late final LanguageServerHandle lsHandle;
    lsHandle = _lsHandle = _editorController.connectLanguageServer(
      workspaceFolderUri: workspace.workspaceFolder,
      sendLanguageServerMessage: (msg) {
        languageServer.languageServerChannel.sink.add(jsonDecode(msg));
      },
      onLanguageServerDisconnected: () {
        lsSubscription?.cancel();
        lsSubscription = null;
        languageServer.stop();
        if (_languageServer == languageServer) {
          _languageServer = null;
        }
        if (_lsHandle == lsHandle) {
          _lsHandle = null;
        }
      },
      onDisplayFileRequested: (uri) async {
        var workspaceFolderStr = workspace.workspaceFolder.toString();
        if (!workspaceFolderStr.endsWith('/')) {
          workspaceFolderStr += '/';
        }
        if (uri.startsWith(workspaceFolderStr)) {
          uri = uri.substring(workspaceFolderStr.length);
        }
        _onFileOpened(uri);
      },
      onRequestFile: (uri) async {
        try {
          return await workspace.readFileAsText(uri);
        } catch (_) {
          return null;
        }
      },
      onLanguageServerProgress: _onLspProgress,
    );
    lsSubscription = languageServer.languageServerChannel.stream.listen((message) {
      lsHandle.deliverLanguageServerMessage(jsonEncode(message));
    });
  }

  Future<void> _saveActiveFile() async {
    if (_activeFile != null) {
      final currentContent = _editorController.getFileContent(_activeFile!);
      if (currentContent != null) {
        if (_workspace != null) {
          await _workspace!.writeFileFromText(_activeFile!, currentContent);
        } else if (_initialFiles != null) {
          _initialFiles![_activeFile!] = utf8.encode(currentContent);
        }
      }
    }
  }

  Future<void> _onFileOpened(String filename) async {
    if (_activeFile == filename) return;

    // Save current file's content back before switching
    await _saveActiveFile();

    setState(() {
      _activeFile = filename;
    });

    // Load the new file into the editor
    String newContent = '';
    if (_workspace != null) {
      newContent = await _workspace!.readFileAsText(filename);
    } else if (_initialFiles != null && _initialFiles![filename] != null) {
      newContent = utf8.decode(_initialFiles![filename]!, allowMalformed: true);
    }

    _editorController.switchFile(filename, content: newContent);
  }

  void _promptAddFile() {
    setState(() {
      _modalState = ModalState(
        title: 'New File',
        contentText: 'Enter file name (e.g., folder/my_file.dart):',
        confirmText: 'Create',
        showInput: true,
        onConfirm: (value) async {
          setState(() => _modalState = null);
          if (value != null && value.trim().isNotEmpty) {
            final path = value.trim();
            if (_files.contains(path)) return; // already exists
            final isFolder = path.endsWith('/');
            final normalizedPath = isFolder ? path.substring(0, path.length - 1) : path;
            if (_workspace != null) {
              if (isFolder) {
                await _workspace!.createFolder(normalizedPath);
              } else {
                await _workspace!.writeFileFromText(path, '');
              }
            } else if (_initialFiles != null) {
              _initialFiles![path] = Uint8List.fromList(utf8.encode(''));
            }
            setState(() {
              _files.add(path);
              _files.sort();
            });
            if (!isFolder) {
              await _onFileOpened(path);
            }
          }
        },
        onCancel: () => setState(() => _modalState = null),
      );
    });
  }

  Future<void> _refreshFiles() async {
    if (_workspace == null) return;
    try {
      final entries = await _workspace!.listDirectory(uri: '', recursive: true, ignoreHidden: true);
      final newFiles = entries.map((e) {
        final isDir = e.type == 'dir' || e.type == 'directory';
        return isDir ? '${e.path}/' : e.path;
      }).toList();

      setState(() {
        _files = newFiles..sort();
        if (_activeFile != null && !_files.contains(_activeFile)) {
          _activeFile = _files.where((f) => !f.endsWith('/')).firstOrNull;
          if (_activeFile != null) _onFileOpened(_activeFile!);
        }
      });
    } catch (e) {
      _consoleStreamController.add('[ERROR] Failed to refresh files: $e');
    }
  }

  void _promptDeleteFile(String path) {
    final isFolder = !_files.contains(path) && _files.any((f) => f.startsWith('$path/'));

    setState(() {
      _modalState = ModalState(
        title: isFolder ? 'Delete Folder' : 'Delete File',
        contentText: 'Are you sure you want to delete "$path"? This cannot be undone.',
        confirmText: 'Delete',
        onConfirm: (_) async {
          setState(() => _modalState = null);

          final filesToDelete = isFolder ? _files.where((f) => f.startsWith('$path/')).toList() : [path];

          for (final f in filesToDelete) {
            if (_workspace != null) {
              await _workspace!.deleteFileSystemEntity(f);
            } else if (_initialFiles != null) {
              _initialFiles!.remove(f);
            }
          }

          setState(() {
            _files.removeWhere((f) => filesToDelete.contains(f));
            if (filesToDelete.contains(_activeFile)) {
              _activeFile = _files.firstOrNull;
              if (_activeFile != null) _onFileOpened(_activeFile!);
            }
          });
        },
        onCancel: () => setState(() => _modalState = null),
      );
    });
  }

  void _promptRenameFile(String oldPath) {
    final isFolder = !_files.contains(oldPath) && _files.any((f) => f.startsWith('$oldPath/'));

    setState(() {
      _modalState = ModalState(
        title: isFolder ? 'Rename Folder' : 'Rename File',
        contentText: 'Enter new name for "$oldPath":',
        confirmText: 'Rename',
        showInput: true,
        initialValue: oldPath,
        onConfirm: (newPath) async {
          setState(() => _modalState = null);
          if (newPath != null && newPath.trim().isNotEmpty && newPath.trim() != oldPath) {
            final path = newPath.trim();
            final filesToRename = isFolder ? _files.where((f) => f.startsWith('$oldPath/')).toList() : [oldPath];

            for (final oldFile in filesToRename) {
              final newFile = isFolder ? oldFile.replaceFirst('$oldPath/', '$path/') : path;
              if (_files.contains(newFile)) continue;

              String content = '';
              if (_workspace != null) {
                try {
                  content = await _workspace!.readFileAsText(oldFile);
                  await _workspace!.writeFileFromText(newFile, content);
                  await _workspace!.deleteFileSystemEntity(oldFile);
                } catch (_) {}
              } else if (_initialFiles != null) {
                content = utf8.decode(_initialFiles![oldFile] ?? []);
                _initialFiles![newFile] = Uint8List.fromList(utf8.encode(content));
                _initialFiles!.remove(oldFile);
              }

              setState(() {
                _files.remove(oldFile);
                _files.add(newFile);
                if (_activeFile == oldFile) {
                  _activeFile = newFile;
                  _onFileOpened(newFile);
                }
              });
            }
            setState(() {
              _files.sort();
            });
          }
        },
        onCancel: () => setState(() => _modalState = null),
      );
    });
  }

  Future<void> _run() async {
    final isBusy = context.read(appTasksProvider).any((t) => t.isRunning);
    if (_workspace == null || isBusy) return;

    await _saveActiveFile();

    await context.runTask('compile', 'Compiling', () async {
      _consoleStreamController.add('[SYSTEM] Compiling');

      try {
        final targetFile = _activeFile ?? 'main.dart';
        final mainUri = _workspace!.workspaceFolder.resolve(targetFile);

        if (_compiler != null && _lastCompilerFile != targetFile) {
          await _compiler!.close();
          _compiler = null;
        }
        _lastCompilerFile = targetFile;

        _compiler ??= await _workspace!.startHotReloadCompiler(mainUri);

        final result = await _compiler!.compile();
        if (result.log.isNotEmpty) {
          _consoleStreamController.add(result.log);
        }

        if (result.code != null && _sandbox != null) {
          _consoleStreamController.add('[SYSTEM] Loading module');
          await _sandbox!.loadModule(code: result.code!);
          await _sandbox!.runMain(mainUri);
          _consoleStreamController.add('[SYSTEM] Application running.');
        } else if (result.code == null) {
          _consoleStreamController.add('[ERROR] Compilation failed.');
        }
      } catch (e, st) {
        _consoleStreamController.add('[ERROR] $e\n$st');
      }
    });
  }

  void _onSandboxReady(Sandbox sandbox) {
    setState(() {
      _sandbox = sandbox;
    });
    sandbox.onConsole.listen((dynamic event) {
      if (event.level.toString().endsWith('error')) {
        _consoleStreamController.add('[ERROR] ${event.message}');
      } else {
        _consoleStreamController.add(event.message);
      }
    });
  }

  @override
  Component build(BuildContext context) {
    final isBusy = context.watch(appTasksProvider).any((t) => t.isRunning);

    return div(classes: 'app-layout', [
      AppHeader(
        isBusy: isBusy,
        onRun: _run,
      ),
      div(classes: 'app-body', [
        SplitPane(
          direction: SplitDirection.horizontal,
          storageKey: 'split-tree-editor',
          initialSplit: 0.2, // 20% width for file tree
          first: Panel(
            title: 'Files',
            icon: 'folder_open',
            controls: [
              IconButton(icon: 'add', small: true, onClick: _promptAddFile, title: 'New File'),
              IconButton(icon: 'refresh', small: true, onClick: _refreshFiles, title: 'Refresh Files'),
            ],
            child: FileTree(
              files: _files,
              activeFile: _activeFile,
              onFileOpened: _onFileOpened,
              onDeleteFile: _promptDeleteFile,
              onRenameFile: _promptRenameFile,
            ),
          ),
          second: SplitPane(
            direction: SplitDirection.horizontal,
            storageKey: 'split-editor-sandbox',
            initialSplit: 0.6, // 60% of the remainder for editor
            first: div(classes: 'editor-container', [
              EditorToolbar(
                activeFile: _activeFile,
              ),
              div(styles: Styles(raw: {'flex': '1 1 auto', 'min-height': '0px'}), [
                Editor(
                  controller: _editorController,
                  onSave: _saveActiveFile,
                ),
              ]),
            ]),
            second: SplitPane(
              direction: SplitDirection.vertical,
              storageKey: 'split-sandbox-console',
              initialSplit: 0.7, // 70% height for sandbox, 30% for console
              first: Panel(
                title: 'Preview',
                icon: 'preview',
                child: SandboxComponent(
                  onReady: _onSandboxReady,
                ),
              ),
              second: ConsoleComponent(stream: _consoleStreamController.stream),
            ),
          ),
        ),
      ]),
      if (_modalState != null)
        ModalDialog(
          title: _modalState!.title,
          contentText: _modalState!.contentText,
          inputPlaceholder: _modalState!.inputPlaceholder,
          confirmText: _modalState!.confirmText,
          showInput: _modalState!.showInput,
          initialValue: _modalState!.initialValue,
          onConfirm: _modalState!.onConfirm,
          onCancel: _modalState!.onCancel,
        ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.app-layout').styles(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      width: 100.percent,
      height: 100.vh,
      backgroundColor: Theme.background,
    ),

    css('.primary-button').styles(
      backgroundColor: Theme.accent,
      color: Colors.white,
      border: Border.unset,
      radius: BorderRadius.all(Radius.circular(4.px)),
      padding: Padding.symmetric(vertical: 6.px, horizontal: 12.px),
      fontSize: 13.px,
      fontWeight: FontWeight.w600,
      cursor: Cursor.pointer,
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.all(6.px),
      raw: {'transition': 'background-color 0.2s'},
    ),
    css('.primary-button:hover').styles(
      backgroundColor: Theme.accentHover,
    ),
    css('.primary-button:disabled').styles(
      backgroundColor: Color('#3a3a3a'),
      color: Color('#888888'),
      cursor: Cursor.notAllowed,
    ),
    css('.primary-button .material-symbols-outlined').styles(
      fontSize: 18.px,
    ),
    css('.app-body').styles(
      display: Display.flex,
      overflow: Overflow.hidden,
      minHeight: 0.px,
      raw: {'flex': '1 1 auto'},
    ),
    css('.editor-container').styles(
      height: 100.percent,
      overflow: Overflow.hidden,
      display: Display.flex,
      flexDirection: FlexDirection.column,
      raw: {'flex': '1 1 auto'},
    ),
  ];
}
