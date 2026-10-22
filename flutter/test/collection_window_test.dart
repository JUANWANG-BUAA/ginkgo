import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/collection_window.dart';

void main() {
  test(
    'refresh follows the existing page anchor when records are inserted',
    () {
      final window = CollectionWindow();
      window.reconcile(List.generate(600, (index) => 'seat-$index'));
      window.select(4);
      expect(window.start, 200);
      window.reconcile([
        ...List.generate(50, (index) => 'new-$index'),
        ...List.generate(600, (index) => 'seat-$index'),
      ]);
      expect(window.start, 250);
      expect(window.end, 300);
      expect(window.pageCount, 13);
    },
  );

  test(
    'deleted anchors clamp pages and an empty query leaves valid bounds',
    () {
      final window = CollectionWindow();
      window.reconcile(List.generate(600, (index) => 'seat-$index'));
      window.select(11);
      window.reconcile(List.generate(70, (index) => 'seat-$index'));
      expect(window.start, 50);
      expect(window.end, 70);
      window.reconcile([]);
      expect(window.page, 0);
      expect(window.start, 0);
      expect(window.end, 0);
      expect(window.pageCount, 1);
    },
  );

  test('a new filter starts at its first result even if old anchors exist', () {
    final window = CollectionWindow();
    final keys = List.generate(600, (index) => 'seat-$index');
    window.reconcile(keys);
    window.select(7);
    window.reconcile(keys, reset: true);
    expect(window.page, 0);
    expect(window.end, 50);
  });
}
