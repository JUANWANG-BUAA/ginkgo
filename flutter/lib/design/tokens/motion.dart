import 'package:flutter/cupertino.dart';

/// Motion tokens respecting system accessibility reduce-motion settings.
abstract final class GinkgoMotion {
  static const normal = Duration(milliseconds: 180);

  static Duration duration(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
