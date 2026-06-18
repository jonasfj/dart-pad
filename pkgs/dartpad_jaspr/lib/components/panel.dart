import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/web.dart' as web;
import '../constants/theme.dart';
import 'icon.dart';

class Panel extends StatefulComponent {
  final String title;
  final String icon;
  final List<Component> controls;
  final Component child;
  final bool initialCollapsed;

  const Panel({
    required this.title,
    required this.icon,
    this.controls = const [],
    required this.child,
    this.initialCollapsed = false,
    super.key,
  });

  @override
  State<Panel> createState() => _PanelState();

  @css
  static List<StyleRule> get styles => [
    css('.panel-section').styles(
      display: Display.flex,
      width: 100.percent,
      height: 100.percent,
      minHeight: 32.px,
      overflow: Overflow.hidden,
      flexDirection: FlexDirection.column,
      raw: {
        'flex': '1 1 auto',
        'transition': 'flex-grow 0.2s ease',
      },
    ),
    css('.panel-section.collapsed').styles(
      height: 32.px,
      minHeight: 32.px,
      raw: {'flex': '0 0 auto'},
    ),
    css('.panel-section.collapsed > .panel-body').styles(
      display: Display.none,
    ),
    css('.panel-header').styles(
      display: Display.flex,
      height: 32.px,
      padding: Padding.only(left: 12.px, right: 8.px),
      cursor: Cursor.pointer,
      userSelect: UserSelect.none,
      justifyContent: JustifyContent.spaceBetween,
      alignItems: AlignItems.center,
      color: Theme.textSecondary,
      fontSize: 11.px,
      fontWeight: FontWeight.w600,
      textTransform: TextTransform.upperCase,
      backgroundColor: Theme.surface,
      raw: {
        'flex': '0 0 32px',
        'border-bottom': '1px solid #3e3e42',
      },
    ),
    css('.panel-header:hover').styles(
      backgroundColor: Theme.surfaceHover,
    ),
    css('.header-label').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.all(6.px),
    ),
    css('.header-icon').styles(
      fontSize: 14.px,
    ),
    css('.header-controls').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.all(4.px),
    ),
    css('.chevron').styles(
      margin: Margin.only(left: 8.px),
      fontSize: 16.px,
      raw: {'transition': 'transform 0.2s ease'},
    ),
    css('.panel-section.collapsed .chevron').styles(
      raw: {'transform': 'rotate(-90deg)'},
    ),
    css('.panel-body').styles(
      display: Display.flex,
      minHeight: 0.px,
      overflow: Overflow.auto,
      flexDirection: FlexDirection.column,
      raw: {'flex': '1 1 0'},
    ),
  ];
}

class _PanelState extends State<Panel> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = component.initialCollapsed;
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'panel-section ${_isCollapsed ? 'collapsed' : ''}'.trim(),
      [
        div(
          classes: 'panel-header',
          events: {
            'click': (web.Event e) => setState(() => _isCollapsed = !_isCollapsed),
          },
          [
            span(
              classes: 'header-label',
              [
                Icon(component.icon, classes: 'header-icon'),
                Component.text(component.title),
              ],
            ),
            div(
              classes: 'header-controls',
              [
                ...component.controls.map(
                  (control) => div(
                    styles: Styles(display: Display.contents),
                    events: {'click': (web.Event e) => e.stopPropagation()},
                    [control],
                  ),
                ),
                Icon('expand_more', classes: 'chevron'),
              ],
            ),
          ],
        ),
        div(classes: 'panel-body', [component.child]),
      ],
    );
  }
}
