// dcpos_app/lib/utils/responsive_extension.dart

import 'package:flutter/material.dart';

const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1000.0;

extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < kMobileBreakpoint;
  bool get isTablet =>
      screenWidth >= kMobileBreakpoint && screenWidth < kTabletBreakpoint;
  bool get isDesktop => screenWidth >= kTabletBreakpoint;
}
