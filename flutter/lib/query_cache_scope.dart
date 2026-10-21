import 'package:flutter/cupertino.dart';

/// Reset retained pages only after Rust has finished clearing its snapshots.
/// A new subtree also discards offstage tab routes and outstanding UI responses.
class QueryCacheScope extends StatefulWidget {
  const QueryCacheScope({super.key, required this.child});
  final Widget child;

  static void invalidate(BuildContext context) =>
      context.findAncestorStateOfType<_QueryCacheScopeState>()?.invalidate();

  @override
  State<QueryCacheScope> createState() => _QueryCacheScopeState();
}

class _QueryCacheScopeState extends State<QueryCacheScope> {
  int generation = 0;
  void invalidate() => setState(() => generation++);
  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(generation), child: widget.child);
}
