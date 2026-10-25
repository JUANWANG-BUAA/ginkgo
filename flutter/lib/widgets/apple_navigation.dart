import 'package:flutter/cupertino.dart';

import '../apple_design.dart';
import '../reminder_badge.dart';

/// macOS reference uses 180–200ms easeInOut for content/state changes.
/// Fade only the incoming snapshot, keeping hit targets and list position stable.
class AppleContentTransition extends StatelessWidget {
  const AppleContentTransition({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object identity;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(identity),
    tween: Tween(begin: 0, end: 1),
    duration: AppleDesign.duration(context, 180),
    curve: Curves.easeInOut,
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: child,
  );
}

/// A persistent desktop destination with pointer, focus and selection feedback.
class AppleNavigationItem extends StatefulWidget {
  const AppleNavigationItem({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.unreadCount = 0,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final int unreadCount;
  final VoidCallback onPressed;
  @override
  State<AppleNavigationItem> createState() => _AppleNavigationItemState();
}

class _AppleNavigationItemState extends State<AppleNavigationItem> {
  bool hovered = false;
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return Semantics(
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: AppleDesign.duration(context, 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.selected
                ? accent.withValues(alpha: 0.11)
                : hovered || focused
                ? CupertinoColors.tertiarySystemFill
                      .resolveFrom(context)
                      .withValues(alpha: 0.45)
                : CupertinoColors.tertiarySystemFill
                      .resolveFrom(context)
                      .withValues(alpha: 0),
            border: Border.all(
              color: focused ? accent : accent.withValues(alpha: 0),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (widget.selected)
                Positioned(
                  left: 3,
                  child: Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                onPressed: widget.onPressed,
                onFocusChange: (value) => setState(() => focused = value),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    ReminderBadge(
                      count: widget.unreadCount,
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: widget.selected
                            ? accent
                            : CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.selected
                              ? accent
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
