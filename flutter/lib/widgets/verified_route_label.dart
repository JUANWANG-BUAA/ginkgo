import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';

/// Reads an in-process identity snapshot, never probes school connectivity.
class VerifiedRouteLabel extends StatefulWidget {
  const VerifiedRouteLabel({
    super.key,
    required this.gateway,
    this.revision = 0,
  });
  final VerifiedRouteGateway gateway;
  final int revision;

  @override
  State<VerifiedRouteLabel> createState() => _VerifiedRouteLabelState();
}

class _VerifiedRouteLabelState extends State<VerifiedRouteLabel>
    with WidgetsBindingObserver {
  int _request = 0;
  bool _visible = false;
  RouteChoice? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) unawaited(_read());
    _visible = visible;
  }

  @override
  void didUpdateWidget(VerifiedRouteLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replaced = oldWidget.gateway != widget.gateway;
    if (replaced) {
      _request++;
      _route = null;
    }
    if (_visible && (replaced || oldWidget.revision != widget.revision)) {
      unawaited(_read());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_visible && state == AppLifecycleState.resumed) unawaited(_read());
  }

  Future<void> _read() async {
    final request = ++_request;
    RouteChoice? route;
    try {
      route = await widget.gateway.lastVerifiedRoute();
    } catch (_) {
      // No observation is not evidence that either route is active.
    }
    if (mounted && request == _request && route != _route) {
      setState(() => _route = route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(switch (_route) {
    RouteChoice.direct => '最近确认：直连',
    RouteChoice.webVpn => '最近确认：WebVPN',
    _ => '路线尚未确认',
  });
}
