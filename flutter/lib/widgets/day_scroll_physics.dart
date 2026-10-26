import 'package:flutter/widgets.dart';

/// Touch flings settle on a day boundary, while wheel and thumb movement remain
/// continuous. The trailing boundary may expose a partial first day.
class DayScrollPhysics extends ScrollPhysics {
  const DayScrollPhysics({required this.dayWidth, super.parent});
  final double dayWidth;

  @override
  DayScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      DayScrollPhysics(dayWidth: dayWidth, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var day = position.pixels / dayWidth;
    if (velocity.abs() > tolerance.velocity) {
      day += velocity.sign * 0.5;
    }
    final target = (day.round() * dayWidth).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
