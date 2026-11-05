import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens.dart';

/// Adds a small touch compression without replacing a control's gestures,
/// focus, keyboard activation or semantics. Scrolling cancels the compression.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  Offset? _origin;
  int? _pointer;
  bool _pressed = false;

  void _release() {
    _origin = null;
    _pointer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(PressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pressed = false;
      _pointer = null;
      _origin = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) {
        if (!widget.enabled || reduced || _pointer != null) return;
        _pointer = event.pointer;
        _origin = event.position;
        setState(() => _pressed = true);
      },
      onPointerMove: (event) {
        if (event.pointer == _pointer &&
            (event.position - _origin!).distance > 8) {
          _release();
        }
      },
      onPointerUp: (event) {
        if (event.pointer == _pointer) _release();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _release();
      },
      child: AnimatedScale(
        scale: _pressed && !reduced && widget.enabled ? 0.985 : 1,
        duration: reduced
            ? Duration.zero
            : _pressed
            ? GinkgoMotion.snappy
            : GinkgoMotion.smooth,
        curve: _pressed ? Curves.easeOutCubic : GinkgoMotion.swiftSpring,
        child: widget.child,
      ),
    );
  }
}
