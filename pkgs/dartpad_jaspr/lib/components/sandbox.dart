import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/theme.dart';
import '../src/dartpad/dartpad.dart';



final class SandboxComponent extends StatefulComponent {
  final void Function(Sandbox) onReady;

  const SandboxComponent({required this.onReady, super.key});

  @override
  State<SandboxComponent> createState() => _SandboxComponentState();

  @css
  static List<StyleRule> get styles => [
    css('.sandbox-container').styles(
      width: 100.percent,
      height: 100.percent,
      backgroundColor: Theme.background,
      overflow: Overflow.hidden,
      display: Display.flex,
    ),
    css('.sandbox-container iframe').styles(
      width: 100.percent,
      height: 100.percent,
      border: Border.unset,
      display: Display.block,
      backgroundColor: Colors.transparent,
      raw: {'flex': '1 1 auto'},
    ),
  ];
}

class _SandboxComponentState extends State<SandboxComponent> {
  final GlobalNodeKey<web.HTMLDivElement> _containerKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Defer DOM attachment until the node is rendered
      web.window.requestAnimationFrame(((num _) {
        final container = _containerKey.currentNode;
        if (container != null) {
          Sandbox.createIFrame(
            container,
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
          ).then((sandbox) {
            component.onReady(sandbox);
          });
        }
      }).toJS);
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      key: _containerKey,
      classes: 'sandbox-container',
      [],
    );
  }
}
