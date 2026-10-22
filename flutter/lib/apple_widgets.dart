import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'app_preferences.dart';
import 'reminder_badge.dart';

export 'application/failure_message.dart';

/// Phone pages keep the native collapsing title. Wide windows use the same
/// section / title / description hierarchy as Swift's AcademicPageHeader.
class ApplePageHeader extends StatelessWidget {
  const ApplePageHeader({
    super.key,
    required this.largeTitle,
    this.trailing,
    this.previousPageTitle,
    this.border,
  });
  final Widget largeTitle;
  final Widget? trailing;
  final String? previousPageTitle;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    if (!AppleDesign.desktop(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle,
        previousPageTitle: previousPageTitle,
        border: border,
        trailing: trailing,
      );
    }
    final title = largeTitle is Text ? (largeTitle as Text).data : null;
    final (section, subtitle, icon) = switch (title) {
      '课表' => ('学业', '按学期与教学周查看课程和考试', CupertinoIcons.calendar),
      '成绩' => ('学业', '查看课程成绩、学分与加权统计', CupertinoIcons.chart_bar_alt_fill),
      '作业' || '学校作业' => ('学业', '区分个人作业状态与助教课程', CupertinoIcons.doc_text),
      '博雅' => ('学业', '查看活动、课程与个人记录', CupertinoIcons.book_solid),
      '研究生教务' => ('学业', '学籍、培养方案与研究生学业查询', CupertinoIcons.building_2_fill),
      '图书馆' => ('空间资源', '选择场馆、区域与可预约时段', CupertinoIcons.book),
      '研讨室' => ('空间资源', '选择场馆并查看可预约空间', CupertinoIcons.person_3),
      '空教室' => ('空间资源', '按校区、日期与节次查询空闲教室', CupertinoIcons.building_2_fill),
      '课程签到' || '签到历史' => ('工作台', '查看课程签到状态与记录', CupertinoIcons.checkmark_seal),
      '待办' => ('工作台', '安排个人任务与截止时间', CupertinoIcons.list_bullet),
      '校园通知' => ('校园', '查看通知与校内资讯', CupertinoIcons.news_solid),
      '今天' || '工作台' => ('工作台', '从今日课程开始安排一天', CupertinoIcons.sun_max),
      '设置' => ('Ginkgo', '管理账号、显示偏好与系统设置', CupertinoIcons.gear_alt),
      _ => ('Ginkgo', null, null),
    };
    final canPop = Navigator.of(context).canPop();
    final accent = CupertinoTheme.of(context).primaryColor;
    return PinnedHeaderSliver(
      child: ColoredBox(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          bottom: false,
          child: Padding(
            key: const Key('desktop-page-heading'),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (canPop) ...[
                  CupertinoButton(
                    key: const Key('desktop-page-back'),
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Semantics(
                      label: '返回上一页',
                      child: const Icon(CupertinoIcons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Icon(icon, size: 22, color: accent)),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        header: true,
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                          child: largeTitle,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 16), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppleEmptyState extends StatelessWidget {
  const AppleEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.action,
    this.onAction,
    this.error = false,
  });
  final String title, description;
  final String? action;
  final VoidCallback? onAction;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Column(
      children: [
        Icon(
          error
              ? CupertinoIcons.exclamationmark_triangle
              : CupertinoIcons.building_2_fill,
          size: 48,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        if (action != null)
          CupertinoButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

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
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          onPressed: () => Navigator.pop(context, value),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                child: value == selected
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

/// Modern inset groups use a continuous corner, a quiet content surface and
/// full row separators. Glass is reserved for navigation and transient menus.
class AppleSection extends StatelessWidget {
  const AppleSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.animateSize = true,
  });
  final List<Widget> children;
  final Widget? header, footer;
  final bool animateSize;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 20 : 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 10),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              child: header!,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesign.pageInset,
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(
              AppleDesign.panelRadius(context),
            ),
            child: _AppleGroupResize(
              enabled: animateSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(
                    AppleDesign.panelRadius(context),
                  ),
                  border: AppleDesign.desktop(context)
                      ? Border.all(
                          color: CupertinoColors.separator
                              .resolveFrom(context)
                              .withValues(alpha: 0.3),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i != children.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 0.5,
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.16),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              child: footer!,
            ),
          ),
      ],
    ),
  );
}

class AppleListTile extends StatelessWidget {
  const AppleListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing,
    this.onTap,
    this.minimumHeight = AppleDesign.rowHeight,
    this.leadingSize = 30,
  });
  final Widget title;
  final Widget? subtitle, additionalInfo, leading, trailing;
  final VoidCallback? onTap;
  final double minimumHeight;
  final double leadingSize;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minimumHeight),
    child: CupertinoListTile(
      title: _wrapText(title),
      subtitle: subtitle == null ? null : _wrapText(subtitle!),
      additionalInfo: additionalInfo,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: AppPreferencesScope.of(context).compactLists ? 6 : 10,
      ),
      leadingToTitle: 12,
      leadingSize: leadingSize,
    ),
  );
  Widget _wrapText(Widget child) => Builder(
    builder: (context) => DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      softWrap: true,
      overflow: TextOverflow.visible,
      child: child,
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
          minimumSize: const Size(36, 36),
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
                  width: 44,
                  height: 44,
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

class _AppleGroupResize extends StatelessWidget {
  const _AppleGroupResize({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
