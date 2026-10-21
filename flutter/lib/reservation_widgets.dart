import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

/// Pointer and press feedback follows the same short, reversible motion used
/// by native controls. The Cupertino button retains keyboard and semantics.
class ReservationActionButton extends StatefulWidget {
  const ReservationActionButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tint = CupertinoColors.systemBlue,
    this.primary = false,
    this.busy = false,
  });
  final Key? buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CupertinoDynamicColor tint;
  final bool primary, busy;
  @override
  State<ReservationActionButton> createState() =>
      _ReservationActionButtonState();
}

class _ReservationActionButtonState extends State<ReservationActionButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final tint = widget.tint.resolveFrom(context);
    final child = widget.busy
        ? CupertinoActivityIndicator(
            color: widget.primary
                ? CupertinoTheme.of(context).primaryContrastingColor
                : tint,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() {
        hovered = false;
        pressed = false;
      }),
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => pressed = true) : null,
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: AnimatedScale(
          scale: pressed && enabled && !MediaQuery.disableAnimationsOf(context)
              ? 0.97
              : 1,
          duration: AppleDesign.duration(context, 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppleDesign.duration(context, 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: hovered && enabled
                    ? tint.withValues(alpha: 0.6)
                    : tint.withValues(alpha: 0.12),
              ),
            ),
            child: CupertinoTheme(
              data: CupertinoTheme.of(context).copyWith(primaryColor: tint),
              child: widget.primary
                  ? CupertinoButton.filled(
                      key: widget.buttonKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onPressed: enabled ? widget.onPressed : null,
                      child: child,
                    )
                  : CupertinoButton.tinted(
                      key: widget.buttonKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      onPressed: enabled ? widget.onPressed : null,
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
