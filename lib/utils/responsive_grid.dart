import 'package:flutter/material.dart';

/// Helper class to calculate responsive grid parameters
class ResponsiveGrid {
  /// Calculate the number of columns based on screen width
  static int getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) {
      return 4; // Large screens (desktop)
    } else if (width >= 900) {
      return 3; // Medium screens (tablet landscape)
    } else if (width >= 600) {
      return 2; // Small screens (tablet portrait)
    } else {
      return 2; // Mobile (always 2 columns for kids app)
    }
  }

  /// Calculate max cross axis extent based on screen width
  static double getMaxCrossAxisExtent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columnCount = getColumnCount(context);

    // Account for padding and spacing
    const horizontalPadding = 32.0; // 16px on each side
    const spacing = 16.0;
    const totalSpacing = (columnCount - 1) * spacing;

    return (width - horizontalPadding - totalSpacing) / columnCount;
  }

  /// Get grid delegate for responsive grid
  static SliverGridDelegate getGridDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: getColumnCount(context),
      childAspectRatio: 0.82,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
    );
  }
}
