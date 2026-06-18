import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../constants/theme.dart';
import 'icon.dart';

class AppHeader extends StatelessComponent {
  final bool isBusy;
  final VoidCallback onRun;

  const AppHeader({
    required this.isBusy,
    required this.onRun,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return header(classes: 'app-header', [
      div(classes: 'header-branding', [
        span(classes: 'app-title', [Component.text('DartPad (experimental)')]),
      ]),
      div(classes: 'header-actions', [
        button(
          classes: 'primary-button',
          events: {'click': (e) => onRun()},
          disabled: isBusy,
          [
            Icon('play_arrow'),
            Component.text('Run'),
          ],
        ),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.app-header').styles(
      height: 48.px,
      backgroundColor: Theme.header,
      display: Display.flex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.spaceBetween,
      padding: Padding.symmetric(horizontal: 16.px),
      raw: {
        'border-bottom': '1px solid #3e3e42',
        'flex': '0 0 auto',
      },
    ),
    css('.app-title').styles(
      fontWeight: FontWeight.w600,
      fontSize: 16.px,
      color: Colors.white,
      letterSpacing: 0.5.px,
    ),
  ];
}
