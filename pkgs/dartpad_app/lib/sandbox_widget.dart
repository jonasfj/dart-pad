import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:dartpad/dartpad.dart';

class SandboxWidget extends StatefulWidget {
  final void Function(Sandbox) onReady;

  const SandboxWidget({super.key, required this.onReady});

  @override
  State<SandboxWidget> createState() => _SandboxWidgetState();
}

class _SandboxWidgetState extends State<SandboxWidget> {
  late String _viewType;
  late web.HTMLDivElement _container;

  @override
  void initState() {
    super.initState();
    _viewType = 'sandbox-view-${identityHashCode(this)}';

    _container = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _container;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSandbox();
    });
  }

  Future<void> _initSandbox() async {
    final sandbox = await Sandbox.createIFrame(
      _container,
      assetBaseUrl: Uri.base.resolve('/asset/worker/'),
      sdkLocation: Uri.parse('dart/'),
      headHtml: '''
<style>
  html, body {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    background-color: #1e1e1e;
    color: #cccccc;
    font-family: sans-serif;
  }
</style>
''',
    );
    widget.onReady(sandbox);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
