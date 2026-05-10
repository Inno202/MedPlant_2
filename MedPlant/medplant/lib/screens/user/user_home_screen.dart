// lib/screens/user/user_home_screen.dart
// Aligned with research proposal — Thaba-Nchu medicinal plant monitoring
// Removed: PlatformTicker (farm market prices — not relevant to study)
// Added: research-relevant plant species, Thaba-Nchu context

import 'package:flutter/material.dart';
import 'package:medplant/widgets/app_bar_widget.dart';
import 'package:medplant/widgets/auth_cta_section.dart';
import 'package:medplant/widgets/badge_row.dart';
import 'package:medplant/widgets/capability_grid.dart';
import 'package:medplant/widgets/hero_section.dart';
import 'package:medplant/widgets/info_grid.dart';
import 'package:medplant/widgets/plant_grid.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/models/plant_model.dart';
import 'package:provider/provider.dart';
import 'package:medplant/providers/user_provider.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.role != null;

    // Thaba-Nchu registered medicinal species (from research survey)
    final List<PlantModel> plants = [
      PlantModel(
        name: "Agapanthus Africanus",
        scientificName: "African Lily",
        imageUrl:
            "https://images.unsplash.com/photo-1501004318641-b39e6451bec6",
        localName: "Ubani",
        family: "Agapanthaceae",
        conservationStatus: "Least Concern",
        healthStatus: "Stressed",
        trendDirection: "Declining",
        locationArea: "Thaba-Nchu, Free State",
      ),
      PlantModel(
        name: "Knowltonia Capensis",
        scientificName: "Brandblare",
        imageUrl:
            "https://images.unsplash.com/photo-1501004318641-b39e6451bec6",
        localName: "Umakhuthula",
        family: "Ranunculaceae",
        conservationStatus: "Vulnerable",
        healthStatus: "Healthy",
        trendDirection: "Stable",
        locationArea: "Thaba-Nchu, Free State",
      ),
      PlantModel(
        name: "Lessertia Frutescens",
        scientificName: "Cancer Bush",
        imageUrl:
            "https://images.unsplash.com/photo-1501004318641-b39e6451bec6",
        localName: "Umswane",
        family: "Fabaceae",
        conservationStatus: "Least Concern",
        healthStatus: "Degraded",
        trendDirection: "Declining",
        locationArea: "Thaba-Nchu, Free State",
        damageLabels: ["Browning", "Lesions", "Stem damage"],
      ),
      PlantModel(
        name: "Hypoxis Hemerocallidea",
        scientificName: "African Potato",
        imageUrl:
            "https://images.unsplash.com/photo-1501004318641-b39e6451bec6",
        localName: "Inkomfe",
        family: "Hypoxidaceae",
        conservationStatus: "Vulnerable",
        healthStatus: "Stressed",
        trendDirection: "Improving",
        locationArea: "Thaba-Nchu, Free State",
      ),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const HeroSection(),
              const SizedBox(height: 15),

              // Core capabilities (research-aligned)
              const SectionHeader(title: "System Capabilities"),
              const CapabilityGrid(),

              // Registered medicinal species
              const SectionHeader(title: "Registered Medicinal Species"),
              PlantGrid(plants: plants),

              const SizedBox(height: 16),
              const InfoGrid(),
              const SizedBox(height: 16),
              if (!isLoggedIn) const AuthCTASection(),
              const SizedBox(height: 16),
              const BadgeRow(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
