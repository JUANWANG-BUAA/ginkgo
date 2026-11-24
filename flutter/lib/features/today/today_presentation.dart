export 'package:ginkgo_mirror/widgets/visual_section.dart'
    show TodaySectionHeader, TodayVisualDivider, TodayVisualSection;

/// Course fields the school left out stay readable: a missing place never
/// renders as an empty line, and the focus card and the course list always
/// agree on the wording.
String todayCoursePlaceLabel(String? place) {
  final text = place?.trim() ?? '';
  return text.isEmpty ? '地点未提供' : text;
}
