// lib/widgets/report_grid.dart
// Responsive grid for ReportCard — see ResponsiveWrapGrid.

import 'package:flutter/material.dart';
import 'report_card.dart';
import 'responsive_wrap_grid.dart';

class ReportGrid extends StatelessWidget {
  final List<ReportCard> reports;

  const ReportGrid({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapGrid(minItemWidth: 300, children: reports);
  }
}
