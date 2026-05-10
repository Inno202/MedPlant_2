import 'package:flutter/material.dart';
import 'package:medplant/constants/app_colors.dart';
import '/models/plant_model.dart';

class PlantDetailScreen extends StatelessWidget {
  final PlantModel plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          plant.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥 HEADER CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 40, 20, 0.08),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 🔥 IMAGE
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.network(
                      plant.imageUrl ?? '',
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.borderSoft,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔥 TITLE
                  Text(
                    plant.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${plant.family} family",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 DESCRIPTION (InfoNote reuse)
            _infoSection(
              icon: Icons.info,
              title: "Description",
              content: plant.description ?? "N/A",
            ),

            const SizedBox(height: 16),

            // 🔥 MEDICINAL USES (InfoNote reuse)
            _infoSection(
              icon: Icons.medical_services,
              title: "Medicinal Uses",
              content: plant.medicinalUses ?? "N/A",
            ),

            const SizedBox(height: 16),

            // 🔥 INFO GRID
            _infoGrid(),
          ],
        ),
      ),
    );
  }

  // 🔥 InfoNote-style reusable section
  Widget _infoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }

  // 🔥 INFO GRID (matches web cards)
  Widget _infoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.8,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _infoItem("Common Name", plant.commonName ?? "N/A"),
        _infoItem("Local Name", plant.localName ?? "N/A"),
        _infoItem("Family", plant.family ?? "N/A"),
        _infoItem("Genus", plant.genus ?? "N/A"),
        _infoItem("Parts Used", plant.partsUsed ?? "N/A"),
        _infoItem("Species ID", plant.speciesId ?? "N/A"),
      ],
    );
  }

  Widget _infoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}