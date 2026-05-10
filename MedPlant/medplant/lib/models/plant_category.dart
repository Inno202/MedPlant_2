// models/plant_category.dart
class PlantCategory {
  final String title;
  final List<String> items;
  final String iconPath; // path to asset icon or use IconData

  PlantCategory({
    required this.title,
    required this.items,
    required this.iconPath,
  });
}