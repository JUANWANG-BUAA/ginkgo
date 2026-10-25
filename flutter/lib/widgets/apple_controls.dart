import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../apple_design.dart';
import 'apple_surfaces.dart';

/// Anchored glass menu used by picker tiles. Returns the selected value, or
/// null when dismissed; positioning keeps every option above the phone tab
/// bar and inside the safe area.
Future<T?> choose<T>(
  BuildContext context,
  String title,
  List<T> values,
  String Function(T) label, {
  T? selected,
}) {
  final box = context.findRenderObject() as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final screen = MediaQuery.sizeOf(context);
  final safe = MediaQuery.paddingOf(context);
  final width = (screen.width - 32).clamp(200.0, 280.0);
  final rowHeight = (MediaQuery.textScalerOf(context).scale(17) * 1.5 + 20)
      .clamp(48.0, 100.0);
  final height = (values.length * rowHeight + 12).clamp(
    60.0,
    screen.height * 0.55,
  );
  final left = (rect.right - width).clamp(16.0, screen.width - width - 16);
  // The phone shell keeps a CupertinoTabBar below the page; menus must stay
  // above it or their lower options become untappable.
  final bottomInset = safe.bottom + (screen.width < 760 ? 64.0 : 0.0);
  final maxTop = (screen.height - bottomInset - height - 12).clamp(
    safe.top + 12,
    screen.height,
  );
  final top =
      (rect.bottom + height < screen.height - bottomInset - 16
              ? rect.bottom
              : rect.top - height)
          .clamp(safe.top + 12, maxTop);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '取消',
    barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
    transitionDuration: AppleDesign.duration(context, 180),
    pageBuilder: (context, animation, secondary) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Semantics(
            label: title,
            scopesRoute: true,
            explicitChildNodes: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff000000).withValues(alpha: 0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: MediaQuery.highContrastOf(context) ? 0 : 20,
                    sigmaY: MediaQuery.highContrastOf(context) ? 0 : 20,
                  ),
                  child: ColoredBox(
                    color: CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.96),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: values.length,
                      itemBuilder: (context, index) {
                        final value = values[index];
                        final isSelected = value == selected;
                        return Semantics(
                          // TalkBack must announce the current choice instead
                          // of an unlabelled check mark decoration.
                          selected: isSelected,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            onPressed: () => Navigator.pop(context, value),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: isSelected
                                      ? Icon(
                                          CupertinoIcons.check_mark,
                                          size: 16,
                                          color: CupertinoTheme.of(context)
                                              .primaryColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label(value),
                                    style: AppleDesign.body.copyWith(
                                      color: CupertinoColors.label.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    transitionBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

class AppleGlassButton extends StatefulWidget {
  const AppleGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String label;
  @override
  State<AppleGlassButton> createState() => _AppleGlassButtonState();
}

class _AppleGlassButtonState extends State<AppleGlassButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    if (AppleDesign.desktop(context)) {
      return Semantics(
        label: widget.label,
        button: true,
        child: CupertinoButton(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(48, 48),
          onPressed: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CupertinoColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: SizedBox(
              width: 34,
              height: 32,
              child: Center(
                child: IconTheme.merge(
                  data: const IconThemeData(size: 19),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final opaque =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    return Semantics(
      label: widget.label,
      button: true,
      child: Listener(
        onPointerDown: widget.onPressed == null
            ? null
            : (_) => setState(() => pressed = true),
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: AnimatedScale(
          scale: pressed && !MediaQuery.disableAnimationsOf(context) ? 0.94 : 1,
          duration: AppleDesign.duration(context, pressed ? 90 : 260),
          curve: pressed ? Curves.easeOut : Curves.easeOutBack,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff000000).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: opaque ? 0 : 16,
                  sigmaY: opaque ? 0 : 16,
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surface.withValues(alpha: opaque ? 1 : 0.72),
                    border: Border.all(
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                      width: 0.7,
                    ),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onPressed,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ApplePickerTile<T> extends StatelessWidget {
  const ApplePickerTile({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final void Function(T) onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchorContext) => AppleListTile(
      title: Text(title),
      subtitle: Text(
        label(value),
        style: TextStyle(
          color: enabled
              ? CupertinoTheme.of(context).primaryColor
              : CupertinoColors.inactiveGray,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_up_chevron_down,
        size: 16,
        color: enabled
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoColors.inactiveGray,
      ),
      onTap: !enabled
          ? null
          : () async {
              final selected = await choose(
                anchorContext,
                title,
                values,
                label,
                selected: value,
              );
              if (selected != null && context.mounted) {
                onSelected(selected);
              }
            },
    ),
  );
}
