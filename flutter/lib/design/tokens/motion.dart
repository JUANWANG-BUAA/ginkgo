import 'package:flutter/cupertino.dart';

/// Motion tokens respecting system accessibility reduce-motion settings.
abstract final class GinkgoMotion {
  // Durations
  static const Duration snappy = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration smooth = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 300);

  // Curves - matching iOS/Swift conventions
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeIn = Curves.easeIn;

  /// Soft return with a small overshoot; not a SwiftUI spring parameter mapping.
  static const Curve swiftSpring = Cubic(0.2, 0.9, 0.3, 1.08);

  /// Monotonic easing for content resizing.
  static const Curve gentleSpring = Curves.decelerate;

  static Duration duration(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  static bool isReducedMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Returns animation with reduce motion awareness
  static Animation<T> withAccessibility<T>(
    BuildContext context,
    Animation<T> animation,
  ) {
    if (isReducedMotion(context)) {
      return AlwaysStoppedAnimation(animation.value);
    }
    return animation;
  }
}
