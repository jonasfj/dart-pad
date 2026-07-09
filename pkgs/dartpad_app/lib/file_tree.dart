import 'package:flutter/material.dart';
import 'package:dartpad/dartpad.dart';

final class FileTreeWidget extends StatefulWidget {
  final Workspace? workspace;
  final String activeFile;
  final String initialRoot;
  final ValueChanged<String> onFileOpened;

  const FileTreeWidget({
    super.key,
    required this.workspace,
    required this.activeFile,
    required this.initialRoot,
    required this.onFileOpened,
  });

  @override
  State<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends State<FileTreeWidget> {
  List<({String path, String type})> _entries = [];
  bool _isLoading = false;
  final Set<String> _expandedFolders = {};
  String? _hoveredPath;
  String _currentRoot = '';

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void didUpdateWidget(FileTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace && widget.workspace != null) {
      _currentRoot = widget.initialRoot;
      _loadDirectory();
    } else if (widget.activeFile != oldWidget.activeFile && widget.activeFile.isNotEmpty) {
      if (_currentRoot.isNotEmpty && !widget.activeFile.startsWith('$_currentRoot/')) {
        // Automatically go up to ensure the active file is visible
        String newRoot = _currentRoot;
        while (newRoot.isNotEmpty && !widget.activeFile.startsWith('$newRoot/')) {
          if (newRoot.contains('/')) {
            newRoot = newRoot.substring(0, newRoot.lastIndexOf('/'));
          } else {
            newRoot = '';
          }
        }
        setState(() => _currentRoot = newRoot);
      }
    }
  }

  Future<void> _loadDirectory() async {
    if (widget.workspace == null) return;
    setState(() => _isLoading = true);
    try {
      final entries = await widget.workspace!.listDirectory(
        uri: '',
        recursive: true,
        ignoreHidden: true,
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('FileTree Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
      } else {
        _expandedFolders.add(path);
      }
    });
  }

  Future<void> _delete(_TreeNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete ${node.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.workspace!.deleteFileSystemEntity(node.path);
        await _loadDirectory();
      } catch (e) {
        debugPrint('Delete Error: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rename(_TreeNode node) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: node.name.replaceAll('/', ''),
        );
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    final parentDir = node.path.contains('/')
        ? node.path.substring(0, node.path.lastIndexOf('/'))
        : '';
    final newPath = parentDir.isEmpty ? newName : '$parentDir/$newName';

    if (newPath == node.path) return;

    setState(() => _isLoading = true);
    try {
      if (node.type == 'file') {
        final content = await widget.workspace!.readFileAsBytes(node.path);
        await widget.workspace!.writeFileFromBytes(newPath, content);
        await widget.workspace!.deleteFileSystemEntity(node.path);
      } else {
        await widget.workspace!.createFolder(newPath);
        for (final entry in _entries) {
          if (entry.path.startsWith(node.path + '/')) {
            final suffix = entry.path.substring(node.path.length);
            final targetPath = newPath + suffix;
            if (entry.type == 'file') {
              final content = await widget.workspace!.readFileAsBytes(
                entry.path,
              );
              await widget.workspace!.writeFileFromBytes(targetPath, content);
            } else {
              await widget.workspace!.createFolder(targetPath);
            }
          }
        }
        await widget.workspace!.deleteFileSystemEntity(node.path);
      }
      await _loadDirectory();
    } catch (e) {
      debugPrint('Rename Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tree = _buildTree(_entries);
    List<_TreeNode> currentNodes = tree;

    if (_currentRoot.isNotEmpty) {
      final parts = _currentRoot.split('/');
      _TreeNode? node;
      List<_TreeNode> searchIn = tree;
      for (final part in parts) {
        node = searchIn.cast<_TreeNode?>().firstWhere(
          (n) => n!.name == '$part/' || n.name == part, 
          orElse: () => null
        );
        if (node == null) break;
        searchIn = node.children;
      }
      if (node != null) {
        currentNodes = node.children;
      } else {
        _currentRoot = '';
      }
    }

    final List<Widget> items = [];
    if (_currentRoot.isNotEmpty) {
      items.add(
        InkWell(
          onTap: () {
            setState(() {
              if (_currentRoot.contains('/')) {
                _currentRoot = _currentRoot.substring(0, _currentRoot.lastIndexOf('/'));
              } else {
                _currentRoot = '';
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                const Icon(Icons.drive_folder_upload, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '..',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    items.addAll(_buildNodes(currentNodes, 0));

    return ListView(children: items);
  }

  List<Widget> _buildNodes(List<_TreeNode> nodes, int depth) {
    final List<Widget> widgets = [];
    for (final node in nodes) {
      final isDir = node.type == 'folder';
      final isActive = node.path == widget.activeFile;
      final isExpanded = _expandedFolders.contains(node.path);
      final isHovered = _hoveredPath == node.path;

      widgets.add(
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredPath = node.path),
          onExit: (_) {
            if (_hoveredPath == node.path) {
              setState(() => _hoveredPath = null);
            }
          },
          child: InkWell(
            onTap: () {
              if (isDir) {
                _toggleFolder(node.path);
              } else {
                widget.onFileOpened(node.path);
              }
            },
            child: Container(
              color: isActive
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : (isHovered ? Colors.white.withValues(alpha: 0.05) : null),
              padding: EdgeInsets.only(
                left: 8.0 + (depth * 16.0),
                top: 4.0,
                bottom: 4.0,
                right: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    isDir
                        ? (isExpanded ? Icons.folder_open : Icons.folder)
                        : Icons.insert_drive_file,
                    size: 16,
                    color: isDir ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (isHovered)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 14),
                          onPressed: () => _rename(node),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 12,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 14),
                          onPressed: () => _delete(node),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 12,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      if (isDir && isExpanded) {
        widgets.addAll(_buildNodes(node.children, depth + 1));
      }
    }
    return widgets;
  }

  List<_TreeNode> _buildTree(List<({String path, String type})> entries) {
    final List<_TreeNode> root = [];
    final Map<String, _TreeNode> map = {};

    entries.sort((a, b) {
      if (a.type != b.type) {
        return a.type == 'folder' ? -1 : 1;
      }
      return a.path.compareTo(b.path);
    });

    for (final entry in entries) {
      final parts = entry.path.split('/');
      final baseName = parts.last;
      final name = entry.type == 'folder' ? '$baseName/' : baseName;
      final parentPath = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : '';

      final node = _TreeNode(path: entry.path, name: name, type: entry.type);
      map[entry.path] = node;

      if (parentPath.isEmpty) {
        root.add(node);
      } else {
        final parent = map[parentPath];
        if (parent != null) {
          parent.children.add(node);
        } else {
          root.add(node);
        }
      }
    }
    return root;
  }
}

class _TreeNode {
  final String path;
  final String name;
  final String type;
  final List<_TreeNode> children = [];

  _TreeNode({required this.path, required this.name, required this.type});
}
