import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_surfaces.dart';

/// Presents the options with the system action sheet.
///
/// A short list — a term, a campus, a slot — uses the system sheet: the
/// options scroll with the page, the current choice is announced, and the
/// dismissal is the system one. The previous hand drawn glass overlay is
/// gone; the sheet needs no anchor, no safe area maths and no tab bar
/// avoidance.
Future<T?> choose<T>(
  BuildContext context,
  String title,
  List<T> values,
  String Function(T) label, {
  T? selected,
}) {
  if (values.isEmpty) return Future<T?>.value();
  if (values.length > 8) {
    return chooseWheel<T>(context, title, values, label, selected: selected);
  }
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final value in values)
          CupertinoActionSheetAction(
            isDefaultAction: value == selected,
            onPressed: () => Navigator.pop(sheetContext, value),
            child: Text(label(value)),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}

/// Presents a long ordered list with the system picker wheel.
///
/// A semester week list or a result page list does not fit an action sheet;
/// the wheel is the native control for a long ordered choice.
Future<T?> chooseWheel<T>(
  BuildContext context,
  String title,
  List<T> values,
  String Function(T) label, {
  T? selected,
}) {
  if (values.isEmpty) return Future<T?>.value();
  final found = selected == null ? -1 : values.indexOf(selected);
  var index = found < 0 ? 0 : found;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheetContext) {
      final textScale = MediaQuery.textScalerOf(sheetContext).scale(1);
      final itemExtent = (44 * textScale.clamp(1.0, 1.8))
          .clamp(44.0, 80.0)
          .toDouble();
      return Container(
        height: (MediaQuery.sizeOf(sheetContext).height * 0.55)
            .clamp(300.0, 440.0)
            .toDouble(),
        color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (MediaQuery.textScalerOf(sheetContext).scale(1) > 1.4) ...[
                Padding(
                  padding: GinkgoSpacing.edgeInsetsPickerTitle,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: GinkgoTypography.headline.fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    CupertinoButton(
                      padding: GinkgoSpacing.edgeInsetsPickerCompactAction,
                      minimumSize: const Size(48, 48),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: GinkgoSpacing.edgeInsetsPickerCompactAction,
                      minimumSize: const Size(48, 48),
                      onPressed: () =>
                          Navigator.pop(sheetContext, values[index]),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ] else
                Row(
                  children: [
                    CupertinoButton(
                      padding: GinkgoSpacing.edgeInsetsPickerAction,
                      minimumSize: const Size(48, 48),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: GinkgoTypography.headline.fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: GinkgoSpacing.edgeInsetsPickerAction,
                      minimumSize: const Size(48, 48),
                      onPressed: () =>
                          Navigator.pop(sheetContext, values[index]),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: index,
                  ),
                  itemExtent: itemExtent,
                  useMagnifier: true,
                  magnification: 1.1,
                  onSelectedItemChanged: (value) => index = value,
                  children: [
                    for (final value in values)
                      Center(child: Text(label(value))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
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
