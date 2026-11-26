import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// The today header carries the current school date context and page refresh
/// action; account settings live in the dedicated workspace destination.
class TodayPageHeader extends StatelessWidget {
  const TodayPageHeader({
    super.key,
    required this.title,
    this.dateLabel,
    required this.busy,
    required this.onRefresh,
  });

  final String title;
  final String? dateLabel;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ApplePageHeader(
    largeTitle: Text(title),
    border: null,
    section: '工作台',
    subtitle: dateLabel,
    icon: CupertinoIcons.sun_max,
    trailing: AppleToolbarButton(
      label: '刷新今天',
      busy: busy,
      onPressed: busy ? null : onRefresh,
      child: busy
          ? const GinkgoActivity()
          : const Icon(CupertinoIcons.refresh, size: 24),
    ),
  );
}

/// Compact date and academic-week anchor shown directly beneath the mobile
/// large title (desktop renders the same text inside [ApplePageHeader]).
class TodayDateContext extends StatelessWidget {
  const TodayDateContext({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (AppleDesign.desktop(context)) return const SizedBox.shrink();
    return Padding(
      key: const Key('today-date-context'),
      padding: GinkgoSpacing.edgeInsetsPage,
      child: Text(
        label,
        style: GinkgoTypography.footnote.copyWith(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Calm all-clear view shown on days with no classes, homework, exams or tasks.
class TodayAllQuietView extends StatelessWidget {
  const TodayAllQuietView({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('today-all-clear'),
    padding: const EdgeInsets.symmetric(
      horizontal: GinkgoSpacing.xl,
      vertical: GinkgoSpacing.xxl,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.sun_max,
          size: GinkgoIconTokens.md,
          color: CupertinoTheme.of(context).primaryColor,
        ),
        const SizedBox(height: GinkgoSpacing.md),
        Text(
          '今天暂无安排',
          style: GinkgoTypography.headline.copyWith(
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        const SizedBox(height: GinkgoSpacing.xs),
        Text(
          schoolDateWeekdayLabel(now),
          style: GinkgoTypography.footnote.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}
