import 'package:flutter/material.dart';

final class HoverPopover extends StatefulWidget {
  final Widget child;
  final Widget popover;

  const HoverPopover({super.key, required this.child, required this.popover});

  @override
  State<HoverPopover> createState() => _HoverPopoverState();
}

class _HoverPopoverState extends State<HoverPopover> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _controller.show(),
        onExit: (_) => _controller.hide(),
        child: OverlayPortal(
          controller: _controller,
          overlayChildBuilder: (context) {
            return CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.transparent,
                  child: widget.popover,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
