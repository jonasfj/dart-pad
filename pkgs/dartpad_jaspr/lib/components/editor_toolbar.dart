import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../constants/theme.dart';
import 'task_status.dart';

class EditorToolbar extends StatelessComponent {
  final String? activeFile;

  const EditorToolbar({
    required this.activeFile,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'toolbar-row', [
      div(classes: 'toolbar-left', []),
      div(classes: 'toolbar-center', [
        span(classes: 'breadcrumbs-path', [Component.text(activeFile ?? '/')]),
      ]),
      TaskStatus(),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.toolbar-row').styles(
      height: 32.px,
      display: Display.flex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.spaceBetween,
      padding: Padding.symmetric(horizontal: 16.px),
      backgroundColor: Theme.background,
      raw: {
        'border-bottom': '1px solid #3e3e42',
        'flex': '0 0 auto',
      },
    ),
    css('.breadcrumbs-path').styles(
      fontSize: 12.px,
      color: Theme.textSecondary,
    ),
    css('.toolbar-left').styles(
      raw: {'flex': '1 1 0'},
    ),
    css('.toolbar-center').styles(
      display: Display.flex,
      justifyContent: JustifyContent.center,
      raw: {'flex': '1 1 0'},
    ),
  ];
}
