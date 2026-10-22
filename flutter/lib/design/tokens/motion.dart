import 'package:flutter/cupertino.dart';

/// Motion tokens respecting system accessibility reduce-motion settings.
abstract final class GinkgoMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 180);
  static const deliberate = Duration(milliseconds: 260);

  static const curveFast = Curves.easeOut;
  static const curveNormal = Curves.easeInOut;
  static const curveSnappy = Curves.easeOutCubic;

  static Duration duration(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
