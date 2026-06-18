import 'dart:math' as math;
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../constants/theme.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

enum SplitDirection {
  horizontal,
  vertical,
}

final class SplitPane extends StatefulComponent {
  final Component first;
  final Component second;
  final SplitDirection direction;
  final double initialSplit;
  final String? storageKey;

  const SplitPane({
    required this.first,
    required this.second,
    this.direction = SplitDirection.horizontal,
    this.initialSplit = 0.5,
    this.storageKey,
    super.key,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();

  @css
  static List<StyleRule> get styles => [
    css('.split-pane-container').styles(
      display: Display.flex,
      position: Position.relative(),
      width: 100.percent,
      height: 100.percent,
      overflow: Overflow.hidden,
    ),
    css('.split-pane-container.horizontal').styles(
      flexDirection: .row,
    ),
    css('.split-pane-container.vertical').styles(
      flexDirection: .column,
    ),
    css('.split-pane-first').styles(
      position: Position.relative(),
      overflow: Overflow.hidden,
    ),
    css('.split-pane-container.horizontal .split-pane-first').styles(
      height: 100.percent,
      raw: {'width': 'calc(var(--split) * 100%)'},
    ),
    css('.split-pane-container.vertical .split-pane-first').styles(
      width: 100.percent,
      raw: {'height': 'calc(var(--split) * 100%)'},
    ),
    css('.split-pane-divider').styles(
      zIndex: ZIndex(10),
      backgroundColor: Colors.transparent,
      raw: {'transition': 'background-color 0.2s ease'},
    ),
    css('.split-pane-divider:hover').styles(
      backgroundColor: Theme.accent,
    ),
    css('.split-pane-container.horizontal .split-pane-divider').styles(
      width: 4.px,
      height: 100.percent,
      cursor: Cursor.colResize,
    ),
    css('.split-pane-container.vertical .split-pane-divider').styles(
      width: 100.percent,
      height: 4.px,
      cursor: Cursor.rowResize,
    ),
    css('.split-pane-second').styles(
      position: Position.relative(),
      overflow: Overflow.hidden,
      flex: Flex(grow: 1),
    ),
    // Horizontal Collapse rules using :has
    css('.split-pane-container.horizontal:has(> .split-pane-first > .panel-section.collapsed) > .split-pane-first').styles(
      width: Unit.auto,
      raw: {'flex': '0 0 auto'},
    ),
    css('.split-pane-container.horizontal:has(> .split-pane-first > .panel-section.collapsed) > .split-pane-second').styles(
      raw: {'flex': '1 1 auto'},
    ),
    css('.split-pane-container.horizontal:has(> .split-pane-second > .panel-section.collapsed) > .split-pane-second').styles(
      width: Unit.auto,
      raw: {'flex': '0 0 auto'},
    ),
    css('.split-pane-container.horizontal:has(> .split-pane-second > .panel-section.collapsed) > .split-pane-first').styles(
      raw: {'flex': '1 1 auto'},
    ),
    // Vertical Collapse rules using :has
    css('.split-pane-container.vertical:has(> .split-pane-first > .panel-section.collapsed) > .split-pane-first').styles(
      height: Unit.auto,
      raw: {'flex': '0 0 auto'},
    ),
    css('.split-pane-container.vertical:has(> .split-pane-first > .panel-section.collapsed) > .split-pane-second').styles(
      raw: {'flex': '1 1 auto'},
    ),
    css('.split-pane-container.vertical:has(> .split-pane-second > .panel-section.collapsed) > .split-pane-second').styles(
      height: Unit.auto,
      raw: {'flex': '0 0 auto'},
    ),
    css('.split-pane-container.vertical:has(> .split-pane-second > .panel-section.collapsed) > .split-pane-first').styles(
      raw: {'flex': '1 1 auto'},
    ),
    // Hide divider when either pane is collapsed
    css('.split-pane-container:has(> .split-pane-first > .panel-section.collapsed) > .split-pane-divider, .split-pane-container:has(> .split-pane-second > .panel-section.collapsed) > .split-pane-divider').styles(
      display: Display.none,
    ),
    // Invisible overlay to catch mouse events while dragging over iframes
    css('.split-pane-overlay').styles(
      position: Position.absolute(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      zIndex: ZIndex(50),
      backgroundColor: Colors.transparent,
    ),
  ];
}

class _SplitPaneState extends State<SplitPane> {
  late double _split;
  bool _isDragging = false;

  JSFunction? _mouseMoveListener;
  JSFunction? _mouseUpListener;

  final GlobalNodeKey<web.HTMLDivElement> _containerKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    _split = component.initialSplit;
    if (kIsWeb && component.storageKey != null) {
      final stored = web.window.localStorage.getItem(component.storageKey!);
      if (stored != null) {
        final val = double.tryParse(stored);
        if (val != null && val > 0.0 && val < 1.0) {
          _split = val;
        }
      }
    }
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  void _removeListeners() {
    if (_mouseMoveListener != null) {
      web.window.removeEventListener('mousemove', _mouseMoveListener!);
      _mouseMoveListener = null;
    }
    if (_mouseUpListener != null) {
      web.window.removeEventListener('mouseup', _mouseUpListener!);
      _mouseUpListener = null;
    }
  }

  void _onMouseDown(web.MouseEvent e) {
    if (!kIsWeb) return;
    e.preventDefault();
    setState(() => _isDragging = true);

    _mouseMoveListener = _onMouseMove.toJS;
    _mouseUpListener = _onMouseUp.toJS;

    web.window.addEventListener('mousemove', _mouseMoveListener!);
    web.window.addEventListener('mouseup', _mouseUpListener!);
  }

  void _onMouseMove(web.MouseEvent e) {
    if (!_isDragging) return;

    final container = _containerKey.currentNode;
    if (container == null) return;

    final rect = container.getBoundingClientRect();

    double newSplit;
    if (component.direction == SplitDirection.horizontal) {
      final x = e.clientX - rect.left;
      newSplit = x / rect.width;
    } else {
      final y = e.clientY - rect.top;
      newSplit = y / rect.height;
    }

    newSplit = math.max(0.05, math.min(0.95, newSplit));

    setState(() {
      _split = newSplit;
    });
  }

  void _onMouseUp(web.MouseEvent e) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    _removeListeners();

    if (component.storageKey != null) {
      web.window.localStorage.setItem(component.storageKey!, _split.toString());
    }
  }

  @override
  Component build(BuildContext context) {
    final isHorizontal = component.direction == SplitDirection.horizontal;

    return div(
      key: _containerKey,
      classes: 'split-pane-container ${isHorizontal ? 'horizontal' : 'vertical'}',
      styles: Styles(
        raw: {
          '--split': '$_split',
          'cursor': _isDragging ? (isHorizontal ? 'col-resize' : 'row-resize') : 'auto',
        },
      ),
      [
        div(classes: 'split-pane-first', [component.first]),
        div(
          classes: 'split-pane-divider',
          events: {'mousedown': (e) => _onMouseDown(e as web.MouseEvent)},
          [],
        ),
        div(classes: 'split-pane-second', [component.second]),
        if (_isDragging) div(classes: 'split-pane-overlay', []),
      ],
    );
  }
}
