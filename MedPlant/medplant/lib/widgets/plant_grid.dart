// widgets/plant_grid.dart
import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import 'plant_card.dart';

class PlantGrid extends StatelessWidget {
  final List<PlantModel> plants;

  const PlantGrid({super.key, required this.plants});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine number of columns based on screen width
    int columns = 1; // mobile default
    if (screenWidth >= 600) columns = 2;
    if (screenWidth >= 900) columns = 3;
    if (screenWidth >= 1200) columns = 4;

    // Calculate childAspectRatio dynamically if needed
    // Example: keep cards roughly square
    final crossAxisSpacing = 12.0;
    final mainAxisSpacing = 12.0;
    final cardWidth = (screenWidth - ((columns - 1) * crossAxisSpacing)) / columns;
    final cardHeight = cardWidth * 1.1; // slight taller for text & image
    final childAspectRatio = cardWidth / cardHeight;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plants.length,
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemBuilder: (context, index) {
        return PlantCard(plant: plants[index]);
      },
    );
  }
}