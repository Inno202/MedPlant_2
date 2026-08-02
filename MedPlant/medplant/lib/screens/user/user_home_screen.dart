// lib/screens/user/user_home_screen.dart
// Registered species are now pulled live from the Firestore 'species'
// collection and mapped to PlantModel before being passed to PlantGrid.
// Everything else (hero, capabilities, info grid, badges, CTA) is unchanged.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:medplant/models/plant_model.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/widgets/auth_cta_section.dart';
import 'package:medplant/widgets/badge_row.dart';
import 'package:medplant/widgets/capability_grid.dart';
import 'package:medplant/widgets/hero_section.dart';
import 'package:medplant/widgets/info_grid.dart';
import 'package:medplant/widgets/plant_grid.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:provider/provider.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  // ── Map a Firestore species document to PlantModel ──────────────────────
  static PlantModel _fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlantModel(
      name: d['name'] ?? 'Unknown species',
      scientificName: d['commonName'],
      imageUrl: (d['imageUrl'] as String?)?.isNotEmpty == true
          ? d['imageUrl'] as String
          : 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6',
      localName: d['localName'],
      family: d['family'],
      conservationStatus: d['conservationStatus'],
      description: d['description'],
      medicinalUses: d['medicinalUses'],
      harvestingSeason: d['harvestingSeason'],
      locationArea: d['locationArea'] ?? 'Thaba-Nchu, Free State',
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.role != null;

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

              // ── System capabilities ────────────────────────────────────
              const SectionHeader(title: "System Capabilities"),
              const CapabilityGrid(),

              // ── Registered species from Firestore ──────────────────────
              const SectionHeader(title: "Registered Medicinal Species"),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('species')
                    .orderBy('addedAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Loading
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _SpeciesLoadingGrid();
                  }

                  // Error
                  if (snapshot.hasError) {
                    return _SpeciesError(message: snapshot.error.toString());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Empty — researcher hasn't added any yet
                  if (docs.isEmpty) {
                    return const _SpeciesEmpty();
                  }

                  final plants =
                      docs.map((doc) => _fromDoc(doc)).toList();

                  return PlantGrid(plants: plants);
                },
              ),

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

// ── Skeleton grid shown while Firestore loads ─────────────────────────────
class _SpeciesLoadingGrid extends StatelessWidget {
  const _SpeciesLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.borderSoft.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primarySoft,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────
class _SpeciesError extends StatelessWidget {
  final String message;
  const _SpeciesError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            left: BorderSide(color: Colors.orange, width: 4)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Could not load species: $message",
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF856404)),
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────
class _SpeciesEmpty extends StatelessWidget {
  const _SpeciesEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.eco, size: 48, color: AppColors.primarySoft),
          const SizedBox(height: 10),
          Text(
            "No species registered yet",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "A researcher can add species via the dashboard.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}