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
          LayoutBuilder(
            builder: (context, constraints) {
              final expanded =
                  constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) <
                  300;
              void select(String value) {
                onChanged?.call(
                  RouteChoice.values.firstWhere(
                    (choice) => choice.name == value,
                  ),
                );
              }

              if (expanded) {
                return Column(
                  children: [
                    for (final entry in group.entries)
                      Semantics(
                        selected: route.name == entry.key,
                        child: CupertinoButton(
                          minimumSize: const Size(48, 48),
                          padding: GinkgoSpacing.edgeInsetsListTile,
                          onPressed: onChanged == null
                              ? null
                              : () => select(entry.key),
                          child: Row(
                            children: [
                              Expanded(child: entry.value),
                              if (route.name == entry.key)
                                const Icon(CupertinoIcons.checkmark_alt),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }
              return IgnorePointer(
                ignoring: onChanged == null,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: route.name,
                  children: group,
                  onValueChanged: (value) {
                    if (value != null && onChanged != null) select(value);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
