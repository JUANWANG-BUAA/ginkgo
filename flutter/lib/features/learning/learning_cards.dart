import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

import 'learning_widgets.dart';

/// Deterministic accent palette for SPOC courses so each course keeps a stable
/// visual identity across the course list and detail hero card.
Color learningCourseAccent(String seed) {
  const palette = <Color>[
    GinkgoColors.resourceBlue,
    GinkgoColors.resourceTeal,
    GinkgoColors.resourcePurple,
    GinkgoColors.accent,
    Color(0xFF059669),
    Color(0xFF4F46E5),
  ];
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

String _courseMonogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '课';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Tactile course card on the SPOC Learning root list.
class LearningCourseCard extends StatelessWidget {
  const LearningCourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  final LearningCourse course;
  final VoidCallback onTap;

  static const double _avatarSize = 44.0;
  static const double _hairline = 0.75;
  static const double _minTouchTarget = 48.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = learningCourseAccent('${course.id}:${course.name}');
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = accent.withValues(alpha: dark ? 0.28 : 0.16);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final hasTeacher = presentText(course.teacher);
    final hasTerm = presentText(course.term);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.sm,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(_minTouchTarget, _minTouchTarget),
        onPressed: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(GinkgoRadii.group),
            border: Border.all(color: border, width: _hairline),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.06),
                      blurRadius: GinkgoSpacing.md,
                      offset: const Offset(0, GinkgoSpacing.xs),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(GinkgoSpacing.pageInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CourseMonogramBadge(
                  letter: _courseMonogram(course.name),
                  accent: accent,
                  size: _avatarSize,
                  dark: dark,
                ),
                const SizedBox(width: GinkgoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GinkgoTypography.headline.copyWith(
                          color: labelColor,
                        ),
                      ),
                      if (hasTeacher || hasTerm) ...[
                        const SizedBox(height: GinkgoSpacing.xs),
                        Wrap(
                          spacing: GinkgoSpacing.sm,
                          runSpacing: GinkgoSpacing.xs,
                          children: [
                            if (hasTeacher)
                              _MetaPill(
                                icon: CupertinoIcons.person_fill,
                                text: course.teacher!,
                                color: accent,
                                dark: dark,
                              ),
                            if (hasTerm)
                              _MetaPill(
                                icon: CupertinoIcons.calendar,
                                text: course.term!,
                                color: secondary,
                                dark: dark,
                                neutral: true,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: GinkgoSpacing.sm),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: GinkgoSpacing.pageInset,
                  color: secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Identity hero banner at the top of LearningCoursePage.
class LearningCourseHeroCard extends StatelessWidget {
  const LearningCourseHeroCard({
    super.key,
    required this.course,
    this.onOpenSource,
  });

  final LearningCourse course;
  final VoidCallback? onOpenSource;

  static const double _avatarSize = 48.0;
  static const double _hairline = 0.75;
  static const double _minTouchTarget = 48.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = learningCourseAccent('${course.id}:${course.name}');
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = accent.withValues(alpha: dark ? 0.3 : 0.2);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final hasTeacher = presentText(course.teacher);
    final hasTerm = presentText(course.term);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.md,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(GinkgoSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CourseMonogramBadge(
                    letter: _courseMonogram(course.name),
                    accent: accent,
                    size: _avatarSize,
                    dark: dark,
                  ),
                  const SizedBox(width: GinkgoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: GinkgoTypography.title.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasTeacher || hasTerm) ...[
                          const SizedBox(height: GinkgoSpacing.xs),
                          Wrap(
                            spacing: GinkgoSpacing.sm,
                            runSpacing: GinkgoSpacing.xs,
                            children: [
                              if (hasTeacher)
                                _MetaPill(
                                  icon: CupertinoIcons.person_fill,
                                  text: course.teacher!,
                                  color: accent,
                                  dark: dark,
                                ),
                              if (hasTerm)
                                _MetaPill(
                                  icon: CupertinoIcons.calendar,
                                  text: course.term!,
                                  color: secondary,
                                  dark: dark,
                                  neutral: true,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (onOpenSource != null) ...[
                const SizedBox(height: GinkgoSpacing.md),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(_minTouchTarget, _minTouchTarget),
                  onPressed: onOpenSource,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GinkgoSpacing.md,
                        vertical: GinkgoSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.globe,
                            size: GinkgoSpacing.pageInset,
                            color: accent,
                          ),
                          const SizedBox(width: GinkgoSpacing.xs),
                          Text(
                            '前往课程官网',
                            style: GinkgoTypography.footnote.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Announcement row card inside a SPOC course.
class LearningAnnouncementCard extends StatelessWidget {
  const LearningAnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final CourseAnnouncement announcement;
  final VoidCallback onTap;

  static const double _iconSize = 32.0;
  static const double _minTouchTarget = 48.0;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_minTouchTarget, _minTouchTarget),
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GinkgoSpacing.pageInset,
          vertical: GinkgoSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GinkgoIconTile(
              icon: CupertinoIcons.bell_fill,
              size: _iconSize,
              color: GinkgoColors.accent,
            ),
            const SizedBox(width: GinkgoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.headline.copyWith(color: labelColor),
                  ),
                  const SizedBox(height: GinkgoSpacing.xs),
                  Text(
                    announcement.publishedAt ?? '发布时间未知',
                    style: GinkgoTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GinkgoSpacing.sm),
            Icon(
              CupertinoIcons.chevron_forward,
              size: GinkgoSpacing.pageInset,
              color: secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only assessment card with color-coded metadata pills.
class LearningAssessmentCard extends StatelessWidget {
  const LearningAssessmentCard({
    super.key,
    required this.item,
    required this.fallbackSummary,
  });

  final CourseAssessment item;
  final String fallbackSummary;

  static const double _iconSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasAny =
        item.startsAt != null || item.dueAt != null || item.score != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GinkgoSpacing.pageInset,
        vertical: GinkgoSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GinkgoIconTile(
            icon: CupertinoIcons.doc_checkmark_fill,
            size: _iconSize,
            color: item.score != null
                ? AppleDesign.statusSuccess.resolveFrom(context)
                : GinkgoColors.resourcePurple,
          ),
          const SizedBox(width: GinkgoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GinkgoTypography.headline.copyWith(color: labelColor),
                ),
                const SizedBox(height: GinkgoSpacing.xs),
                if (!hasAny)
                  Text(
                    fallbackSummary,
                    style: GinkgoTypography.caption.copyWith(color: secondary),
                  )
                else
                  Wrap(
                    spacing: GinkgoSpacing.sm,
                    runSpacing: GinkgoSpacing.xs,
                    children: [
                      if (item.startsAt != null)
                        _MetaPill(
                          icon: CupertinoIcons.play_fill,
                          text: '开始 ${item.startsAt}',
                          color: secondary,
                          dark: dark,
                          neutral: true,
                        ),
                      if (item.dueAt != null)
                        _MetaPill(
                          icon: CupertinoIcons.clock_fill,
                          text: '截止 ${item.dueAt}',
                          color: AppleDesign.statusPending.resolveFrom(context),
                          dark: dark,
                        ),
                      if (item.score != null)
                        _MetaPill(
                          icon: CupertinoIcons.star_fill,
                          text: '成绩 ${item.score}',
                          color: AppleDesign.statusSuccess.resolveFrom(context),
                          dark: dark,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseMonogramBadge extends StatelessWidget {
  const _CourseMonogramBadge({
    required this.letter,
    required this.accent,
    required this.size,
    required this.dark,
  });

  final String letter;
  final Color accent;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final monogram = Text(
      letter,
      style: GinkgoTypography.title.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: dark ? 0.34 : 0.2),
            accent.withValues(alpha: dark ? 0.18 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(GinkgoRadii.panel),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: monogram),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.dark,
    this.neutral = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool dark;
  final bool neutral;

  static const double _iconSize = 11.0;

  @override
  Widget build(BuildContext context) {
    final bg = neutral
        ? (dark ? const Color(0xFF232936) : const Color(0xFFF0F2F7))
        : color.withValues(alpha: dark ? 0.2 : 0.11);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GinkgoRadii.badge),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GinkgoSpacing.sm,
          vertical: GinkgoSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: GinkgoSpacing.xs),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GinkgoTypography.caption2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
