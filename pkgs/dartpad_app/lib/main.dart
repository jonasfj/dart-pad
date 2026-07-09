import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import 'package:dartpad/dartpad.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';

import 'src/load_example.dart';
import 'editor_interop.dart';
import 'editor_widget.dart';
import 'sandbox_widget.dart';
import 'task_provider.dart';
import 'console_widget.dart';
import 'hover_popover.dart';
import 'file_tree.dart';
import 'panel.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const DartPadApp(),
    ),
  );
}

class DartPadApp extends StatelessWidget {
  const DartPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DartPad App',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1c2834),
          brightness: Brightness.dark,
          surface: const Color(0xFF1c2834),
          onSurface: Colors.white,
          onPrimary: const Color(0xff40C4FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF15202b),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1c2834),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const DartPadScreen(),
    );
  }
}

class DartPadScreen extends StatefulWidget {
  const DartPadScreen({super.key});

  @override
  State<DartPadScreen> createState() => _DartPadScreenState();
}

class _DartPadScreenState extends State<DartPadScreen> {
  final EditorController _editorController = EditorController();

  Map<String, Uint8List>? _initialFiles;
  String? _activeFile;
  String _exampleRoot = '';
  Sandbox? _sandbox;
  Workspace? _workspace;
  HotReloadCompiler? _compiler;
  String? _lastCompilerFile;

  bool _isLoading = true;
  String _statusMessage = 'Loading...';

  // Panel states
  bool _leftPanelCollapsed = false;
  bool _consoleCollapsed = false;
  bool _editorCollapsed = false;
  bool _previewCollapsed = false;

  final StreamController<String> _systemConsoleController =
      StreamController.broadcast();
  final StreamController<String> _appConsoleController =
      StreamController.broadcast();
  final ValueNotifier<int> _consoleTabController = ValueNotifier<int>(0);
  StreamSubscription? _sandboxConsoleSub;

  @override
  void initState() {
    super.initState();
    _editorController.onRun = _run;
    _editorController.onSave = () async {
      await _saveActiveFile();
      _logSystem('File saved.');
    };
    if (kIsWeb) {
      _initStateWeb();
    }
  }

  @override
  void dispose() {
    _systemConsoleController.close();
    _appConsoleController.close();
    _sandboxConsoleSub?.cancel();
    _consoleTabController.dispose();
    super.dispose();
  }

  void _logSystem(String message, {bool isError = false}) {
    _systemConsoleController.add(
      isError ? '[ERROR] $message' : '[SYSTEM] $message',
    );
  }

  Future<void> _initStateWeb() async {
    try {
      final queryParams = Uri.base.queryParameters;
      final package = queryParams['package'];
      final version = queryParams['version'];
      final path = queryParams['path'] ?? '/';
      final archive = queryParams['archive'];

      Map<String, Uint8List> files = {};
      
      if (archive != null) {
        files = await loadFromArchiveUrl(archiveUrl: archive, path: path);
      } else if (package != null) {
        files = await loadExample(package: package, version: version, path: path);
      } else {
        // Default to a known package if nothing is provided
        files = await loadExample(package: 'retry', path: '/');
      }

      _initialFiles = files;
      if (files.isEmpty) {
        files['main.dart'] = Uint8List.fromList([]);
      }

      String queryPath = path;
      if (queryPath.startsWith('/')) {
        queryPath = queryPath.substring(1);
      }
      
      String exampleRoot = '';
      String searchPath = queryPath;
      if (searchPath.endsWith('/')) {
        searchPath = searchPath.substring(0, searchPath.length - 1);
      }
      
      while (true) {
        String testPubspec = searchPath.isEmpty ? 'pubspec.yaml' : '$searchPath/pubspec.yaml';
        if (files.containsKey(testPubspec)) {
          exampleRoot = searchPath;
          break;
        }
        if (searchPath.isEmpty) break;
        if (searchPath.contains('/')) {
          searchPath = searchPath.substring(0, searchPath.lastIndexOf('/'));
        } else {
          searchPath = '';
        }
      }

      bool isFlutter = false;
      final targetPubspec = exampleRoot.isEmpty ? 'pubspec.yaml' : '$exampleRoot/pubspec.yaml';
      if (files.containsKey(targetPubspec)) {
        try {
          final pubspecStr = utf8.decode(files[targetPubspec]!, allowMalformed: true);
          debugPrint('Analyzing pubspec: $targetPubspec\n$pubspecStr');
          final yaml = loadYaml(pubspecStr);
          if (yaml is YamlMap) {
            final env = yaml['environment'];
            if (env is YamlMap && env.containsKey('flutter')) {
              isFlutter = true;
            }
            final depsKeys = ['dependencies', 'dev_dependencies'];
            for (final depKey in depsKeys) {
              final deps = yaml[depKey];
              if (deps is YamlMap) {
                if (deps.containsKey('flutter')) isFlutter = true;
                for (final value in deps.values) {
                  if (value is YamlMap && value['sdk'] == 'flutter') {
                    isFlutter = true;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing pubspec: $e');
        }
      } else {
        debugPrint('targetPubspec not found: $targetPubspec. Available files: ${files.keys.take(10).join(', ')}');
      }

      debugPrint('Detected SDK: ${isFlutter ? "flutter" : "dart"}');

      final dartPad = await DartPad.create(
        assetBaseUrl: Uri.base.resolve('/asset/worker/'),
        sdkLocation: Uri.parse(isFlutter ? 'flutter/' : 'dart/'),
      );

      final workspace = await dartPad.createWorkspace();

      String? activeFile;
      if (queryPath.endsWith('.dart') && files.containsKey(queryPath)) {
        activeFile = queryPath;
      } else {
        final candidates = [
          if (exampleRoot.isNotEmpty) '$exampleRoot/bin/example.dart',
          if (exampleRoot.isNotEmpty) '$exampleRoot/example.dart',
          if (exampleRoot.isNotEmpty) '$exampleRoot/bin/main.dart',
          if (exampleRoot.isNotEmpty) '$exampleRoot/main.dart',
          if (exampleRoot.isNotEmpty) '$exampleRoot/lib/main.dart',
          if (exampleRoot.isNotEmpty) '$exampleRoot/lib/example.dart',
          'bin/example.dart',
          'example.dart',
          'bin/main.dart',
          'main.dart',
          'lib/main.dart',
          'lib/example.dart',
          files.keys.where((f) => f.endsWith('.dart')).firstOrNull,
          files.keys.where((f) => f.endsWith('.md')).firstOrNull,
          files.keys.firstOrNull,
        ];
        activeFile = candidates.whereType<String>().firstWhere((f) => files.keys.contains(f));
      }

      setState(() {
        _activeFile = activeFile;
        _exampleRoot = exampleRoot;
        _isLoading = false;
        _statusMessage = 'Ready';
      });

      _editorController.switchFile(
        activeFile,
        content: utf8.decode(files[activeFile]!, allowMalformed: true),
      );

      for (final entry in _initialFiles!.entries) {
        await workspace.writeFileFromBytes(entry.key, entry.value);
      }
      _workspace = workspace;
      _initialFiles = null;

      final hasPubspec = await workspace.fileExist('pubspec.yaml');
      if (hasPubspec) {
        await _runPubGet();
      }

      final languageServer = await workspace.startLanguageServer();

      late LanguageServerHandle lsHandle;
      lsHandle = _editorController.connectLanguageServer(
        workspaceFolderUri: workspace.workspaceFolder,
        sendLanguageServerMessage: (msg) {
          languageServer.languageServerChannel.sink.add(jsonDecode(msg));
        },
        onLanguageServerDisconnected: () {
          languageServer.stop();
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
        onLanguageServerProgress: (token, kind, title) {
          final taskId = 'lsp_$token';
          final provider = context.read<TaskProvider>();
          if (kind == 'begin') {
            provider.startTask(
              taskId,
              title,
              expiration: const Duration(seconds: 60),
            );
          } else if (kind == 'report' && title.isNotEmpty) {
            provider.updateTask(taskId, title);
          } else if (kind == 'end') {
            provider.endTask(taskId);
          }
        },
      );

      languageServer.languageServerChannel.stream.listen((message) {
        lsHandle.deliverLanguageServerMessage(jsonEncode(message));
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading: $e';
      });
      _logSystem('Error loading: $e', isError: true);
    }
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
    await _saveActiveFile();
    setState(() {
      _activeFile = filename;
    });

    String newContent = '';
    if (_workspace != null) {
      newContent = await _workspace!.readFileAsText(filename);
    } else if (_initialFiles != null && _initialFiles![filename] != null) {
      newContent = utf8.decode(_initialFiles![filename]!, allowMalformed: true);
    }
    _editorController.switchFile(filename, content: newContent);
  }

  Future<void> _runPubGet() async {
    if (_workspace == null) return;
    if (!mounted) return;

    await _saveActiveFile();

    String pubDir = '';
    if (_activeFile != null) {
      String searchPath = _activeFile!;
      while (true) {
        String dir = searchPath;
        if (dir.contains('/')) {
          dir = dir.substring(0, dir.lastIndexOf('/'));
        } else {
          dir = '';
        }
        
        final pubspecPath = dir.isEmpty ? 'pubspec.yaml' : '$dir/pubspec.yaml';
        if (await _workspace!.fileExist(pubspecPath)) {
          pubDir = dir;
          break;
        }
        
        if (dir.isEmpty) {
          // If we reached root and didn't find it, use exampleRoot or fallback to ''
          pubDir = _exampleRoot;
          break;
        }
        searchPath = dir;
      }
    }

    // Auto-expand system console if it's collapsed
    if (_consoleCollapsed) {
      setState(() => _consoleCollapsed = false);
    }
    _consoleTabController.value = 1; // 1 = Debug Log
    _systemConsoleController.add('[CLEAR]');
    _logSystem('Running pub get in ${pubDir.isEmpty ? "workspace root" : "'$pubDir'"}...');
    await context.read<TaskProvider>().runTask(
      'pub_get',
      'Running pub get',
      () async {
        setState(() => _statusMessage = 'Running pub get...');
        try {
          final result = await _workspace!.pub(uri: pubDir, command: 'get');
          _logSystem(result.log);
          setState(() => _statusMessage = 'Ready');
        } catch (e) {
          _logSystem('Pub get failed: $e', isError: true);
          setState(() => _statusMessage = 'Pub get failed');
        }
      },
      expiration: const Duration(seconds: 60),
    );
  }

  Future<void> _formatCode() async {
    _editorController.format();
  }

  Future<void> _run() async {
    if (_workspace == null) return;
    await _saveActiveFile();
    if (!mounted) return;

    if (_consoleCollapsed) {
      setState(() => _consoleCollapsed = false);
    }
    _consoleTabController.value = 0; // 0 = Output

    _appConsoleController.add('[CLEAR]');
    _systemConsoleController.add('[CLEAR]');

    await context.read<TaskProvider>().runTask(
      'compile',
      'Compiling',
      () async {
        setState(() => _statusMessage = 'Compiling...');
        _logSystem('Compiling...');
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
          _logSystem(result.log);

          if (result.code != null && _sandbox != null) {
            setState(() => _statusMessage = 'Loading module...');
            await _sandbox!.loadModule(code: result.code!);
            await _sandbox!.runMain(mainUri);
            setState(() => _statusMessage = 'Running');
          } else if (result.code == null) {
            setState(() => _statusMessage = 'Compilation failed');
            _logSystem('Compilation failed: ${result.log}', isError: true);
          }
        } catch (e) {
          setState(() => _statusMessage = 'Error: $e');
          _logSystem('Run error: $e', isError: true);
        }
      },
    );
  }

  void _onSandboxReady(Sandbox sandbox) {
    _sandbox = sandbox;
    _sandboxConsoleSub?.cancel();
    _sandboxConsoleSub = sandbox.onConsole.listen((event) {
      _appConsoleController.add(event.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text(_statusMessage)));
    }

    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasks.where((t) => t.isRunning).toList();

    Widget leftPanel = CollapsiblePanel(
      title: 'File Browser',
      icon: Icons.folder,
      isCollapsed: _leftPanelCollapsed,
      direction: Axis.horizontal,
      onToggle: () =>
          setState(() => _leftPanelCollapsed = !_leftPanelCollapsed),
      child: FileTreeWidget(
        workspace: _workspace,
        activeFile: _activeFile ?? '',
        initialRoot: _exampleRoot,
        onFileOpened: _onFileOpened,
      ),
    );

    Widget editorPanel = CollapsiblePanel(
      title: 'Editor',
      titleWidget: _buildBreadcrumbs(_activeFile ?? ''),
      icon: Icons.code,
      isCollapsed: _editorCollapsed,
      direction: Axis.vertical,
      onToggle: () => setState(() => _editorCollapsed = !_editorCollapsed),
      child: EditorWidget(controller: _editorController),
    );

    Widget middlePanel;
    if (_consoleCollapsed) {
      middlePanel = Column(
        children: [
          Expanded(child: editorPanel),
          CollapsiblePanel(
            title: 'Output / Debug',
            titleWidget: Row(
              children: [
                _buildConsoleTab('Output', 0),
                _buildConsoleTab('Debug Log', 1),
              ],
            ),
            icon: Icons.terminal,
            isCollapsed: true,
            direction: Axis.vertical,
            onToggle: () => setState(() => _consoleCollapsed = false),
            child: const SizedBox.shrink(),
          ),
        ],
      );
    } else {
      middlePanel = SplitView(
        viewMode: SplitViewMode.Vertical,
        gripSize: 8.0,
        indicator: const ThinSplitIndicator(viewMode: SplitViewMode.Vertical),
        activeIndicator: const ThinSplitIndicator(
          viewMode: SplitViewMode.Vertical,
          isActive: true,
        ),
        children: [
          editorPanel,
          CollapsiblePanel(
            title: 'Output / Debug',
            titleWidget: Row(
              children: [
                _buildConsoleTab('Output', 0),
                _buildConsoleTab('Debug Log', 1),
              ],
            ),
            icon: Icons.terminal,
            isCollapsed: false,
            direction: Axis.vertical,
            onToggle: () => setState(() => _consoleCollapsed = true),
            child: ValueListenableBuilder<int>(
              valueListenable: _consoleTabController,
              builder: (context, index, _) {
                return IndexedStack(
                  index: index,
                  children: [
                    ConsoleWidget(stream: _appConsoleController.stream),
                    ConsoleWidget(stream: _systemConsoleController.stream),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    Widget previewPanel = CollapsiblePanel(
      title: 'Preview',
      icon: Icons.web,
      isCollapsed: _previewCollapsed,
      direction: Axis.horizontal,
      onToggle: () => setState(() => _previewCollapsed = !_previewCollapsed),
      child: SandboxWidget(onReady: _onSandboxReady),
    );

    Widget rightPanel = previewPanel;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const FlutterLogo(size: 24),
            const SizedBox(width: 8),
            const Text('DartPad'),
            const SizedBox(width: 16),
            HoverPopover(
              popover: _buildTasksPopover(provider),
              child: Row(
                children: [
                  if (tasks.isNotEmpty)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.check, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    tasks.isNotEmpty
                        ? '${tasks.length} tasks running'
                        : 'Ready',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Pub Get'),
            onPressed: _runPubGet,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.format_align_left),
            label: const Text('Format'),
            onPressed: _formatCode,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff40C4FF),
              foregroundColor: Colors.black,
            ),
            onPressed: _run,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          if (_leftPanelCollapsed) leftPanel,
          Expanded(
            child: SplitView(
              viewMode: SplitViewMode.Horizontal,
              gripSize: 8.0,
              indicator: const ThinSplitIndicator(
                viewMode: SplitViewMode.Horizontal,
              ),
              activeIndicator: const ThinSplitIndicator(
                viewMode: SplitViewMode.Horizontal,
                isActive: true,
              ),
              children: [
                if (!_leftPanelCollapsed) leftPanel,
                middlePanel,
                if (!_previewCollapsed) rightPanel,
              ],
            ),
          ),
          if (_previewCollapsed) rightPanel,
        ],
      ),
    );
  }

  Widget _buildConsoleTab(String title, int index) {
    return ValueListenableBuilder<int>(
      valueListenable: _consoleTabController,
      builder: (context, current, _) {
        final isActive = current == index;
        return InkWell(
          onTap: () {
            if (_consoleCollapsed) {
              setState(() => _consoleCollapsed = false);
            }
            _consoleTabController.value = index;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumbs(String path) {
    if (path.isEmpty) {
      return const Text(
        'Editor',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    }
    final parts = path.split('/');
    final List<Widget> children = [];
    for (int i = 0; i < parts.length; i++) {
      children.add(
        Text(
          parts[i],
          style: TextStyle(
            fontSize: 13,
            color: i == parts.length - 1 ? Colors.white : Colors.grey,
            fontWeight: i == parts.length - 1 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
      if (i < parts.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Text('/', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        );
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildTasksPopover(TaskProvider provider) {
    if (provider.tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('No tasks', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.tasks.map((t) {
              final isRunning = t.isRunning;
              final timeStr = isRunning
                  ? 'running'
                  : '${t.finished!.difference(t.started).inMilliseconds}ms';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    isRunning
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green,
                          ),
                    const SizedBox(width: 12),
                    Text(
                      t.title,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isRunning ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

final class ThinSplitIndicator extends StatelessWidget {
  final SplitViewMode viewMode;
  final bool isActive;

  const ThinSplitIndicator({
    super.key,
    required this.viewMode,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // transparent background for the 8px grip area
      child: Center(
        child: Container(
          width: viewMode == SplitViewMode.Vertical ? 32 : 2,
          height: viewMode == SplitViewMode.Horizontal ? 32 : 2,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
