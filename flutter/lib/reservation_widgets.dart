import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'loading_widgets.dart';

/// The shared reservation action control, aligned with native button styles:
/// one continuous shape, no border ring, 48dp minimum hit height, short press
/// scale. `primary` renders the single filled action of a context; inline
/// rows use the compact tinted capsule. The tint defaults to the theme accent
/// and should only be overridden with semantic status colors.
class ReservationActionButton extends StatefulWidget {
  const ReservationActionButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tint,
    this.primary = false,
    this.busy = false,
    this.compact = false,
  });
  final Key? buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CupertinoDynamicColor? tint;
  final bool primary, busy, compact;
  @override
  State<ReservationActionButton> createState() =>
      _ReservationActionButtonState();
}

class _ReservationActionButtonState extends State<ReservationActionButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const leaf = GinkgoActivity(size: 16);
    final content = widget.busy
        // A filled action paints the leaf in its contrasting foreground so the
        // brand mark stays visible on the accent fill.
        ? widget.primary
              ? ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    CupertinoDynamicColor.resolve(
                      CupertinoTheme.of(context).primaryContrastingColor,
                      context,
                    ),
                    BlendMode.srcIn,
                  ),
                  child: leaf,
                )
              : leaf
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 13)
        : const EdgeInsets.symmetric(horizontal: 16);
    final button = widget.primary
        ? CupertinoButton.filled(
            key: widget.buttonKey,
            padding: padding,
            minimumSize: const Size(0, 48),
            onPressed: enabled ? widget.onPressed : null,
            child: content,
          )
        : CupertinoButton.tinted(
            key: widget.buttonKey,
            padding: padding,
            minimumSize: const Size(0, 48),
            onPressed: enabled ? widget.onPressed : null,
            child: content,
          );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Listener(
        onPointerDown: enabled && !reduceMotion
            ? (_) => setState(() => pressed = true)
            : null,
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: AnimatedScale(
          scale: pressed ? 0.96 : 1,
          duration: AppleDesign.duration(context, 120),
          curve: Curves.easeOut,
          child: CupertinoTheme(
            data: widget.tint == null
                ? CupertinoTheme.of(context)
                : CupertinoTheme.of(context).copyWith(
                    primaryColor: widget.tint!.resolveFrom(context),
                  ),
            child: button,
          ),
        ),
      ),
    );
  }
}
