import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class Icon extends StatelessComponent {
  final String icon;
  final String? classes;

  const Icon(this.icon, {this.classes, super.key});

  @override
  Component build(BuildContext context) {
    return span(
      classes: 'material-symbols-outlined${classes != null ? ' $classes' : ''}',
      [Component.text(icon)],
    );
  }
}
