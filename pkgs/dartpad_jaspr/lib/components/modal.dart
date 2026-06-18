import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:universal_web/web.dart' as web;
import '../constants/theme.dart';

class ModalDialog extends StatefulComponent {
  final String title;
  final String contentText;
  final String? inputPlaceholder;
  final String confirmText;
  final bool showInput;
  final String? initialValue;
  final void Function(String?) onConfirm;
  final void Function() onCancel;

  const ModalDialog({
    required this.title,
    required this.contentText,
    this.inputPlaceholder,
    required this.confirmText,
    this.showInput = false,
    this.initialValue,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  @override
  State<ModalDialog> createState() => _ModalDialogState();

  @css
  static List<StyleRule> get styles => [
    css('.modal-overlay').styles(
      position: Position.fixed(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      backgroundColor: Theme.overlay,
      display: Display.flex,
      justifyContent: JustifyContent.center,
      alignItems: AlignItems.center,
      zIndex: ZIndex(1000),
    ),
    css('.modal-content').styles(
      backgroundColor: Theme.surface,
      raw: {'border-radius': '6px', 'box-shadow': '0 4px 20px rgba(0,0,0,0.5)'},
      minWidth: 300.px,
      overflow: Overflow.hidden,
      display: Display.flex,
      flexDirection: FlexDirection.column,
    ),
    css('.modal-header').styles(
      padding: Padding.all(16.px),
      fontSize: 14.px,
      fontWeight: FontWeight.w600,
      color: Theme.textPrimary,
      backgroundColor: Theme.surfaceActive,
      raw: {'border-bottom': '1px solid #3e3e42', 'margin': '0'},
    ),
    css('.modal-body').styles(
      padding: Padding.all(16.px),
      fontSize: 13.px,
      color: Theme.textSecondary,
    ),
    css('.modal-text').styles(
      margin: Margin.zero,
    ),
    css('.modal-input').styles(
      width: 100.percent,
      padding: Padding.all(8.px),
      margin: Margin.only(top: 8.px),
      backgroundColor: Theme.background,
      color: Theme.textPrimary,
      raw: {'border': '1px solid #3e3e42', 'border-radius': '4px', 'outline': 'none', 'box-sizing': 'border-box'},
    ),
    css('.modal-input:focus').styles(
      raw: {'border': '1px solid #0175C2'},
    ),
    css('.modal-actions').styles(
      display: Display.flex,
      padding: Padding.all(16.px),
      gap: Gap.all(8.px),
      raw: {'border-top': '1px solid #3e3e42', 'justify-content': 'flex-end'},
    ),
    css('.modal-btn').styles(
      padding: Padding.symmetric(horizontal: 16.px, vertical: 6.px),
      fontSize: 12.px,
      cursor: Cursor.pointer,
      raw: {'border-radius': '4px', 'border': 'none', 'outline': 'none'},
    ),
    css('.modal-btn.cancel').styles(
      backgroundColor: Colors.transparent,
      color: Theme.textSecondary,
    ),
    css('.modal-btn.cancel:hover').styles(
      backgroundColor: Theme.surfaceHover,
      color: Theme.textPrimary,
    ),
    css('.modal-btn.confirm').styles(
      backgroundColor: Theme.primary,
      color: Colors.white,
    ),
    css('.modal-btn.confirm:hover').styles(
      backgroundColor: Theme.primaryHover,
    ),
  ];
}

class _ModalDialogState extends State<ModalDialog> {
  String _inputValue = '';

  @override
  void initState() {
    super.initState();
    _inputValue = component.initialValue ?? '';
  }

  void _handleConfirm() {
    component.onConfirm(component.showInput ? _inputValue : null);
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'modal-overlay',
      events: {'click': (web.Event e) => component.onCancel()},
      [
        div(
          classes: 'modal-content',
          events: {'click': (web.Event e) => e.stopPropagation()},
          [
            h3(classes: 'modal-header', [Component.text(component.title)]),
            div(classes: 'modal-body', [
              p(classes: 'modal-text', [Component.text(component.contentText)]),
              if (component.showInput)
                input(
                  type: InputType.text,
                  classes: 'modal-input',
                  value: _inputValue,
                  attributes: {'placeholder': component.inputPlaceholder ?? ''},
                  events: {
                    'input': (web.Event e) {
                      final target = e.target as web.HTMLInputElement;
                      _inputValue = target.value;
                    },
                    'keydown': (web.Event e) {
                      final keyEvent = e as web.KeyboardEvent;
                      if (keyEvent.key == 'Enter') {
                        _handleConfirm();
                      } else if (keyEvent.key == 'Escape') {
                        component.onCancel();
                      }
                    }
                  },
                )
            ]),
            div(classes: 'modal-actions', [
              button(
                classes: 'modal-btn cancel',
                events: {'click': (web.Event e) => component.onCancel()},
                [Component.text('Cancel')]
              ),
              button(
                classes: 'modal-btn confirm',
                events: {'click': (web.Event e) => _handleConfirm()},
                [Component.text(component.confirmText)]
              ),
            ]),
          ]
        )
      ]
    );
  }
}
