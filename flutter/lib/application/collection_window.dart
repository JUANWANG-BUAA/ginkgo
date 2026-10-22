/// Bounded presentation of an already-loaded result, independent of transport.
/// Refresh follows the first item on the page; changed queries explicitly reset.
class CollectionWindow {
  CollectionWindow({this.pageSize = 50}) : assert(pageSize > 0);
  final int pageSize;
  List<String> _keys = const [];
  int page = 0;
  int get count => _keys.length;
  int get pageCount => count == 0 ? 1 : (count / pageSize).ceil();
  int get start => page * pageSize;
  int get end => (start + pageSize).clamp(0, count);

  void reconcile(Iterable<String> keys, {bool reset = false}) {
    final anchor = _keys.isEmpty ? null : _keys[start];
    _keys = keys.toList(growable: false);
    if (reset) {
      page = 0;
    } else {
      final index = anchor == null ? -1 : _keys.indexOf(anchor);
      page = index < 0 ? page.clamp(0, pageCount - 1) : index ~/ pageSize;
    }
  }

  void select(int value) => page = value.clamp(0, pageCount - 1);
}
