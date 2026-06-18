import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/web.dart' as web;
import '../constants/theme.dart';
import 'icon.dart';

class IconButton extends StatelessComponent {
  final String icon;
  final String? title;
  final void Function() onClick;
  final bool small;

  const IconButton({
    required this.icon,
    required this.onClick,
    this.title,
    this.small = false,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return button(
      classes: small ? 'icon-button-small' : 'icon-button',
      attributes: title != null ? {'title': title!} : null,
      events: {'click': (web.Event e) {
        e.stopPropagation();
        onClick();
      }},
      [
        Icon(icon),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.icon-button, .icon-button-small').styles(
      backgroundColor: Colors.transparent,
      border: Border.unset,
      color: Theme.textPrimary,
      cursor: Cursor.pointer,
      display: Display.flex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.center,
      radius: BorderRadius.all(Radius.circular(4.px)),
      padding: Padding.all(6.px),
      raw: {'transition': 'background-color 0.2s, color 0.2s'},
    ),
    css('.icon-button:hover, .icon-button-small:hover').styles(
      backgroundColor: Theme.surfaceHover,
      color: Colors.white,
    ),
    css('.icon-button .material-symbols-outlined').styles(
      fontSize: 20.px,
    ),
    css('.icon-button-small .material-symbols-outlined').styles(
      fontSize: 16.px,
    ),
  ];
}
