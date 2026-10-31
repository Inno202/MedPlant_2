// widgets/capability_grid.dart
import 'package:flutter/material.dart';
import '../models/capability.dart';
import '../data/capabilities.dart';
import 'capability_card.dart';

class CapabilityGrid extends StatelessWidget {
  const CapabilityGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int gridColumns = 1;
    double mobileCardHeight = 150; // fixed height for mobile

    if (screenWidth >= 600) gridColumns = 2;
    if (screenWidth >= 900) gridColumns = 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: coreCapabilities.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridColumns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: gridColumns == 1 ? 3 : 1.2,
      ),
      itemBuilder: (context, index) {
        final card = CapabilityCard(capability: coreCapabilities[index]);

        // On mobile, wrap in fixed height; on large screens, allow intrinsic height
        if (screenWidth < 600) {
          return SizedBox(height: mobileCardHeight, child: card);
        } else {
          return IntrinsicHeight(child: card);
        }
      },
    );
  }
}