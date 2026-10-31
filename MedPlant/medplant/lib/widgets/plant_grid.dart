// widgets/plant_grid.dart
// Responsive grid of species cards. Tapping a card opens its detail page.

import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import 'plant_card.dart';
import 'responsive_wrap_grid.dart';

class PlantGrid extends StatelessWidget {
  final List<PlantModel> plants;

  const PlantGrid({super.key, required this.plants});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapGrid(
      minItemWidth: 280,
      children: plants.map((plant) => PlantCard(plant: plant)).toList(),
    );
  }
}
