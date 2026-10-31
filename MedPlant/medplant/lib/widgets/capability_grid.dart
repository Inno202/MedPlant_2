// widgets/capability_grid.dart
// Responsive: 1 column on phones, more on tablets/desktop. Card height
// follows its content (the old fixed aspect ratio clipped text on small
// phones and left gaps on large screens).
import 'package:flutter/material.dart';
import '../data/capabilities.dart';
import 'capability_card.dart';
import 'responsive_wrap_grid.dart';

class CapabilityGrid extends StatelessWidget {
  const CapabilityGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ResponsiveWrapGrid(
        minItemWidth: 280,
        maxColumns: 3,
        children: coreCapabilities
            .map((c) => CapabilityCard(capability: c))
            .toList(),
      ),
    );
  }
}
