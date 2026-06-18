import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/theme.dart';
import 'icon_button.dart';
import 'icon.dart';

class _TreeNode {
  final String name;
  final String fullPath;
  bool isFolder;
  final Map<String, _TreeNode> children = {};

  _TreeNode({required this.name, required this.fullPath, this.isFolder = false});
}

final class FileTree extends StatefulComponent {
  final List<String> files;
  final String? activeFile;
  final void Function(String filename) onFileOpened;
  final void Function(String filename)? onDeleteFile;
  final void Function(String filename)? onRenameFile;

  const FileTree({
    required this.files,
    this.activeFile,
    required this.onFileOpened,
    this.onDeleteFile,
    this.onRenameFile,
    super.key,
  });

  @override
  State<FileTree> createState() => _FileTreeState();

  @css
  static List<StyleRule> get styles => [
    css('.file-tree').styles(
      width: 100.percent,
      height: 100.percent,
      overflow: Overflow.auto,
      color: Theme.textPrimary,
      fontSize: 13.px,
      backgroundColor: Theme.surface,
    ),
    css('.file-tree-list').styles(
      padding: Padding.zero,
      margin: Margin.zero,
      listStyle: ListStyle.none,
    ),
    css('.file-tree-item').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.spaceBetween,
      padding: Padding.symmetric(vertical: 4.px, horizontal: 16.px),
      cursor: Cursor.pointer,
      userSelect: UserSelect.none,
    ),
    css('.file-item-left').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      overflow: Overflow.hidden,
      raw: {'white-space': 'nowrap', 'text-overflow': 'ellipsis'},
    ),
    css('.file-item-actions').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.all(2.px),
      visibility: Visibility.hidden,
    ),
    css('.file-tree-item:hover .file-item-actions').styles(
      visibility: Visibility.visible,
    ),
    css('.file-item-actions .icon-button-small').styles(
      padding: Padding.all(2.px),
    ),
    css('.file-icon').styles(
      fontSize: 16.px,
      margin: Margin.only(right: 6.px),
      color: Theme.textSecondary,
      raw: {
        'line-height': '1',
        'vertical-align': 'middle',
        'flex-shrink': '0',
      },
    ),
    css('.file-tree-item:hover').styles(
      color: Colors.white,
      backgroundColor: Theme.surfaceHover,
    ),
    css('.file-tree-item.active').styles(
      color: Colors.white,
      backgroundColor: Theme.surfaceActive,
    ),
  ];
}

class _FileTreeState extends State<FileTree> {
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    _expandAllInitial();
  }

  @override
  void didUpdateComponent(FileTree oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.files != component.files) {
      _expandAllInitial();
    }
  }

  void _expandAllInitial() {
    for (final path in component.files) {
      final parts = path.split('/');
      String currentPath = '';
      for (int i = 0; i < parts.length - 1; i++) {
        currentPath = currentPath.isEmpty ? parts[i] : '$currentPath/${parts[i]}';
        _expandedFolders.add(currentPath);
      }
    }
  }

  _TreeNode _buildTree() {
    final root = _TreeNode(name: '', fullPath: '', isFolder: true);
    for (final path in component.files) {
      final parts = path.split('/');
      _TreeNode current = root;
      String currentPath = '';
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty && i == parts.length - 1) continue;
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
        final isLast = i == parts.length - 1 || (i == parts.length - 2 && parts.last.isEmpty);

        if (!current.children.containsKey(part)) {
          current.children[part] = _TreeNode(
            name: part,
            fullPath: currentPath,
            isFolder: !isLast || path.endsWith('/'),
          );
        } else if (path.endsWith('/') && isLast) {
          current.children[part]!.isFolder = true;
        }
        current = current.children[part]!;
      }
    }
    return root;
  }

  Iterable<Component> _buildNode(_TreeNode node, int depth) sync* {
    if (node.name.isNotEmpty) {
      final isExpanded = _expandedFolders.contains(node.fullPath);
      final isActive = node.fullPath == component.activeFile;

      String iconName;
      if (node.isFolder) {
        iconName = isExpanded ? 'folder_open' : 'folder';
      } else {
        if (node.name.endsWith('.dart')) {
          iconName = 'code';
        } else if (node.name.endsWith('.md')) {
          iconName = 'article';
        } else if (node.name.endsWith('.yaml') || node.name.endsWith('.json')) {
          iconName = 'data_object';
        } else if (node.name.endsWith('.html')) {
          iconName = 'html';
        } else {
          iconName = 'description';
        }
      }

      yield li(
        classes: 'file-tree-item ${isActive ? 'active' : ''}',
        styles: Styles(padding: Padding.only(left: (depth * 12 + 16).px, top: 4.px, bottom: 4.px, right: 16.px)),
        events: {
          'click': (web.Event e) {
            if (node.isFolder) {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(node.fullPath);
                } else {
                  _expandedFolders.add(node.fullPath);
                }
              });
            } else {
              component.onFileOpened(node.fullPath);
            }
          }
        },
        [
          div(classes: 'file-item-left', [
            Icon(iconName, classes: 'file-icon'),
            span([.text(node.isFolder ? '${node.name}/' : node.name)]),
          ]),
          div(classes: 'file-item-actions', [
            if (component.onRenameFile != null)
              IconButton(icon: 'edit', small: true, title: 'Rename', onClick: () => component.onRenameFile!(node.fullPath)),
            if (component.onDeleteFile != null)
              IconButton(icon: 'delete', small: true, title: 'Delete', onClick: () => component.onDeleteFile!(node.fullPath)),
          ])
        ],
      );

      if (node.isFolder && isExpanded) {
        final children = node.children.values.toList()
          ..sort((nodeA, nodeB) {
            if (nodeA.isFolder != nodeB.isFolder) return nodeA.isFolder ? -1 : 1;
            return nodeA.name.compareTo(nodeB.name);
          });

        for (final child in children) {
          yield* _buildNode(child, depth + 1);
        }
      }
    } else {
      final children = node.children.values.toList()
        ..sort((nodeA, nodeB) {
          if (nodeA.isFolder != nodeB.isFolder) return nodeA.isFolder ? -1 : 1;
          return nodeA.name.compareTo(nodeB.name);
        });

      for (final child in children) {
        yield* _buildNode(child, 0);
      }
    }
  }

  @override
  Component build(BuildContext context) {
    final rootNode = _buildTree();

    return div(
      classes: 'file-tree',
      [
        ul(
          classes: 'file-tree-list',
          _buildNode(rootNode, 0).toList(),
        ),
      ],
    );
  }
}
