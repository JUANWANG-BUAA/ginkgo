import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/workspace_catalog.dart';

void main() {
  test('feature ids are unique and resolvable', () {
    final ids = workspaceDestinations
        .map((destination) => destination.id)
        .toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(destinationById(id)?.id, id);
    }
    expect(destinationById('missing'), isNull);
  });

  test('mobile tabs are contiguous, unique and start at the workbench', () {
    final tabs = mobileDestinations;
    expect(tabs.map((destination) => destination.mobileTab).toList(), [
      0,
      1,
      2,
      3,
      4,
    ]);
    expect(tabs.first.id, 'today');
    expect(
      tabs.map((destination) => destination.id).toSet().length,
      tabs.length,
    );
    for (final destination in tabs) {
      expect(destination.mobileLabel ?? destination.title, isNotEmpty);
    }
  });

  test('every destination has a unique, non-empty icon', () {
    final icons = <String>{};
    for (final destination in workspaceDestinations) {
      final icon = destination.icon;
      expect(icon.codePoint, isNot(0), reason: destination.id);
      expect(icon.fontFamily, isNotNull, reason: destination.id);
      final key =
          '${icon.fontFamily}/${icon.fontPackage ?? ''}/${icon.codePoint}';
      expect(
        icons.add(key),
        isTrue,
        reason: '${destination.id} reuses ${icon.fontFamily}:${icon.codePoint}',
      );
    }
  });

  test('desktop sidebar is grouped and settings stays in the footer', () {
    final grouped = <String>[];
    for (final section in WorkspaceSection.values) {
      final entries = sidebarDestinations(section);
      expect(entries, isNotEmpty, reason: section.title);
      for (final destination in entries) {
        expect(destination.section, section);
        expect(destination.sidebar, isTrue);
        grouped.add(destination.id);
      }
    }
    expect(grouped.toSet().length, grouped.length);
    expect(footerDestinations.map((destination) => destination.id), [
      'settings',
    ]);
    final reservations = destinationById('reservations')!;
    expect(reservations.sidebar, isFalse);
    expect(reservations.mobileTab, 4);
    // Every destination either shows in the sidebar or a mobile tab, so no
    // feature can be registered without a way to reach it.
    for (final destination in workspaceDestinations) {
      expect(
        destination.sidebar ||
            destination.footer ||
            destination.mobileTab != null,
        isTrue,
        reason: destination.id,
      );
    }
  });
}
