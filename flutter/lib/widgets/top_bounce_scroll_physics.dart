import 'package:flutter/widgets.dart';

/// Bounces only past the top edge (so pull-to-refresh keeps working) and clamps
/// at the bottom edge.
///
/// A bouncing bottom edge lets a hard fling overshoot while the page's sections
/// are still loading or resizing; the extent changes under the spring and the
/// list visibly shudders. Stopping at the bottom removes that feedback loop.
class TopBounceScrollPhysics extends BouncingScrollPhysics {
  const TopBounceScrollPhysics({super.parent});

  @override
  TopBounceScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      TopBounceScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value > position.pixels &&
        position.pixels >= position.maxScrollExtent) {
      // Already at (or beyond) the bottom and pushing further.
      return value - position.pixels;
    }
    if (value > position.maxScrollExtent &&
        position.pixels < position.maxScrollExtent) {
      // Crossing the bottom edge in this update.
      return value - position.maxScrollExtent;
    }
    return 0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (velocity > 0 || position.pixels > position.maxScrollExtent) {
      return const ClampingScrollPhysics().createBallisticSimulation(
        position,
        velocity,
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
