// lib/widgets/report_grid.dart
// Wrap-based grid for ReportCard, same pattern as PlantGrid — card height
// is driven by content instead of a fixed GridView aspect ratio.

import 'package:flutter/material.dart';
import 'report_card.dart';

class ReportGrid extends StatelessWidget {
  final List<ReportCard> reports;

  const ReportGrid({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int columns = 1; // mobile default
    if (screenWidth >= 600) columns = 2;
    if (screenWidth >= 900) columns = 3;
    if (screenWidth >= 1200) columns = 4;

    final spacing = 12.0;
    final outerPadding = 24.0;
    final cardWidth =
        (screenWidth - outerPadding - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children: reports
          .map((card) => SizedBox(width: cardWidth, child: card))
          .toList(),
    );
  }
}