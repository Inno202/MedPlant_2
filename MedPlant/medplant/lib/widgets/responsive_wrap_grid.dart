// lib/widgets/responsive_wrap_grid.dart
// Wrap-based responsive grid. Card height follows its content, and the
// column count / card width come from the space the grid ACTUALLY has
// (LayoutBuilder), not the full screen width — the old calculation
// assumed fixed outer padding and overflowed inside padded or
// width-capped parents.

import 'package:flutter/material.dart';

class ResponsiveWrapGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  /// Minimum comfortable card width; columns are added while each card
  /// can stay at least this wide.
  final double minItemWidth;
  final int maxColumns;

  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.minItemWidth = 300,
    this.maxColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      var columns = ((width + spacing) / (minItemWidth + spacing)).floor();
      columns = columns.clamp(1, maxColumns);
      final itemWidth = (width - spacing * (columns - 1)) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((c) => SizedBox(width: itemWidth.floorToDouble(), child: c))
            .toList(),
      );
    });
  }
}
