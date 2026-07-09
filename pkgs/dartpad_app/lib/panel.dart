import 'package:flutter/material.dart';

final class CollapsiblePanel extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final IconData icon;
  final Widget child;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Axis direction;
  final List<Widget>? actions;
  final bool collapsible;

  const CollapsiblePanel({
    super.key,
    required this.title,
    this.titleWidget,
    required this.icon,
    required this.child,
    required this.isCollapsed,
    required this.onToggle,
    this.direction = Axis.horizontal,
    this.actions,
    this.collapsible = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isCollapsed) {
      if (direction == Axis.horizontal) {
        content = InkWell(
          key: const ValueKey('collapsed-horizontal'),
          onTap: onToggle,
          child: Container(
            width: 40,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Icon(icon, size: 20, color: Colors.grey),
                const SizedBox(height: 16),
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      } else {
        content = InkWell(
          key: const ValueKey('collapsed-vertical'),
          onTap: onToggle,
          child: Container(
            height: 36,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                if (collapsible)
                  Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey),
              ],
            ),
          ),
        );
      }
    } else {
      content = Column(
        key: const ValueKey('expanded'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      titleWidget ??
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                ),
                ...?actions,
                if (collapsible)
                  IconButton(
                    icon: Icon(
                      direction == Axis.horizontal
                          ? Icons.keyboard_arrow_left
                          : Icons.keyboard_arrow_down,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onToggle,
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axis: direction == Axis.horizontal ? Axis.horizontal : Axis.vertical,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: content,
    );
  }
}
