// data/plant_categories.dart
import '../models/plant_category.dart';

final List<PlantCategory> plantCategories = [
  PlantCategory(
    title: "Plants Monitored",
    items: [
      "Agapanthus Africanus",
      "Knowltonia Capensis",
      "Lessertia frutescens",
      "And many more..."
    ],
    iconPath: "assets/icons/plants.png",
  ),
  PlantCategory(
    title: "Contributors to Medicinal Plants Degradation",
    items: [
      "Land Use Change",
      "Pollution",
      "Climate Change",
      "Overexploitation"
    ],
    iconPath: "assets/icons/degradation.png",
  ),
  PlantCategory(
    title: "Indigenous Knowledge Integration",
    items: [
      "Community Indicators",
      "Local Observations",
      "Traditional Practices",
      "Oral Histories"
    ],
    iconPath: "assets/icons/indigenous.png",
  ),
];