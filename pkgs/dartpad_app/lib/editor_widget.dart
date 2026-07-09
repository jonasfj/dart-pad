import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'editor_interop.dart';

class EditorWidget extends StatefulWidget {
  final EditorController controller;

  const EditorWidget({super.key, required this.controller});

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'editor-view-${identityHashCode(widget.controller)}';

    // Register the editor container as a platform view.
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = widget.controller.editorContainer;
      if (container == null) {
        return web.HTMLDivElement()..innerText = 'Editor not initialized';
      }
      container.style.width = '100%';
      container.style.height = '100%';
      return container;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
