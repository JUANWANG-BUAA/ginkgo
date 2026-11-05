import 'package:flutter/cupertino.dart';

/// Shadow specifications matching Apple design language precision.
/// Each elevation level includes shadow color, blur radius, and offset.
abstract final class GinkgoElevation {
  /// No elevation - flat surface
  static const List<BoxShadow> none = [];

  /// 1pt elevation - subtle depth for interactive elements
  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0a000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// 2pt elevation - slight floating effect
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// 4pt elevation - standard floating card
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1a000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  /// 8pt elevation - emphasized floating surface
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1f000000), blurRadius: 12, offset: Offset(0, 6)),
  ];

  /// 12pt elevation - high emphasis modal/sheet
  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  /// 16pt elevation - modal dialogs and top-level content
  static const List<BoxShadow> xxl = [
    BoxShadow(color: Color(0x2d000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
}
