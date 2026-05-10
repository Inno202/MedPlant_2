// widgets/info_card.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String type; // "check", "times", "indigenous"

  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.type = "check",
  });

  Color _getStripColor() {
    switch (type) {
      case "check":
      case "times":
      case "indigenous":
      default:
        return AppColors.primary;
    }
  }

  IconData _getBulletIcon(int index) {
    switch (type) {
      case "check":
        return Icons.check_circle;
      case "times":
        return Icons.cancel;
      case "indigenous":
        const icons = [
          Icons.people,       // Community Indicators
          Icons.remove_red_eye, // Local Observations
          Icons.park,         // Traditional Practices
          Icons.chat,         // Oral Histories
        ];
        if (index < icons.length) return icons[index];
        return Icons.circle;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top colored strip (now takes full width of card)
          Container(
            height: 4,
            margin: const EdgeInsets.only(top: 1.5),
            decoration: BoxDecoration(
              color: _getStripColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: _getStripColor()),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // List items
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _getBulletIcon(index),
                          size: 16,
                          color: _getStripColor(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}