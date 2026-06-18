import 'dart:async';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../constants/theme.dart';
import 'panel.dart';
import 'icon_button.dart';

class ConsoleComponent extends StatefulComponent {
  final Stream<String>? stream;

  const ConsoleComponent({this.stream, super.key});

  @override
  State<ConsoleComponent> createState() => _ConsoleState();

  @css
  static List<StyleRule> get styles => [
    css('.console-output').styles(
      backgroundColor: Theme.background,
      padding: Padding.all(8.px),
      fontFamily: const FontFamily.list([
        FontFamily('Google Sans Mono'),
        FontFamilies.monospace,
      ]),
      fontSize: 12.px,
      whiteSpace: WhiteSpace.preWrap,
      minHeight: 0.px,
      raw: {'flex': '1 1 auto', 'overflow-y': 'auto', 'overflow-wrap': 'anywhere'},
    ),
    css('.log-error').styles(color: Theme.error),
    css('.log-system').styles(color: Theme.system, fontWeight: FontWeight.w500),
    css('.log-metrics').styles(
      color: Theme.textSecondary,
      fontSize: 11.px,
      textAlign: TextAlign.right,
      fontStyle: FontStyle.italic,
    ),
  ];
}

class _ConsoleState extends State<ConsoleComponent> {
  final List<String> _logs = [];
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    if (component.stream != null) {
      _subscription = component.stream!.listen((log) {
        setState(() => _logs.add(log));
      });
    }
  }

  @override
  void didUpdateComponent(ConsoleComponent oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.stream != component.stream) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void clear() {
    setState(() => _logs.clear());
  }

  @override
  Component build(BuildContext context) {
    return Panel(
      title: 'Console',
      icon: 'terminal',
      controls: [
        IconButton(
          icon: 'block',
          title: 'Clear',
          small: true,
          onClick: clear,
        ),
      ],
      child: div(
        classes: 'console-output',
        _logs.map((log) {
          String className = '';
          if (log.startsWith('[ERROR]')) {
            className = 'log-error';
            log = log.substring('[ERROR]'.length).trim();
          } else if (log.startsWith('[SYSTEM]')) {
            className = 'log-system';
            log = log.substring('[SYSTEM]'.length).trim();
          } else if (log.startsWith('[METRIC]')) {
            className = 'log-metrics';
            log = log.substring('[METRIC]'.length).trim();
          }
          return div(classes: className, [Component.text(log)]);
        }).toList(),
      ),
    );
  }
}
