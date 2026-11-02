import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/design/tokens/typography.dart';

/// Persistent network-route choice shown on the login page.
class LoginRouteSelector extends StatelessWidget {
  const LoginRouteSelector({
    super.key,
    required this.route,
    required this.onChanged,
  });

  final RouteChoice route;
  final ValueChanged<RouteChoice>? onChanged;

  @override
  Widget build(BuildContext context) {
    final group = <String, Widget>{
      'automatic': Text('自动'),
      'direct': Text('仅直连'),
      'webVpn': Text('仅 WebVPN'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: GinkgoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '网络路线',
            style: GinkgoTypography.footnote.copyWith(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          IgnorePointer(
            ignoring: onChanged == null,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: route.name,
              children: group,
              onValueChanged: (value) {
                if (onChanged == null) return;
                if (value == null) return;
                onChanged!(
                  RouteChoice.values.firstWhere(
                    (choice) => choice.name == value,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
