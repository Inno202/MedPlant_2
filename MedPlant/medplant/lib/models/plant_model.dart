// lib/models/plant_model.dart
// Aligned with Research Proposal: Intelligent Mobile-Based Biodiversity
// Monitoring System for Medicinal Plants – Thaba-Nchu

class PlantModel {
  final String name;
  final String? scientificName;
  final String imageUrl;

  // Basic taxonomy
  final String? description;
  final String? medicinalUses;
  final String? commonName;
  final String? localName;       // Sesotho / Barolong local name
  final String? family;
  final String? genus;
  final String? partsUsed;
  final String? speciesId;

  // ── ML Pipeline outputs (RF Functions 1, 2, 3) ──────────────────────────
  /// ML Function 1 – Species Identification confidence score (0.0–1.0)
  final double? identificationConfidence;

  /// ML Function 2 – Trend-based health classification
  /// Values: 'Healthy' | 'Stressed' | 'Degraded'
  final String? healthStatus;

  /// ML Function 2 – Trend direction across prior submissions
  /// Values: 'Improving' | 'Stable' | 'Declining'
  final String? trendDirection;

  /// ML Function 3 – Damage types detected in submitted image
  /// e.g. ['Leaf discolouration', 'Wilting', 'Browning']
  final List<String>? damageLabels;

  // ── Submission / monitoring metadata ────────────────────────────────────
  final String? gpsCoordinates;     // lat,lng string
  final String? locationArea;       // e.g. 'Thaba-Nchu, Free State'
  final String? environmentalCondition; // e.g. 'Hot', 'Wet', 'Cold'
  final String? observerNotes;      // user-entered observation at capture time
  final String? submissionDate;
  final int? reportCount;           // total community reports for this species

  // ── Conservation status ──────────────────────────────────────────────────
  /// e.g. 'Least Concern' | 'Vulnerable' | 'Endangered'
  final String? conservationStatus;
  final String? harvestingSeason;

  const PlantModel({
    required this.name,
    this.scientificName,
    required this.imageUrl,
    this.description,
    this.medicinalUses,
    this.commonName,
    this.localName,
    this.family,
    this.genus,
    this.partsUsed,
    this.speciesId,
    // ML outputs
    this.identificationConfidence,
    this.healthStatus,
    this.trendDirection,
    this.damageLabels,
    // Monitoring metadata
    this.gpsCoordinates,
    this.locationArea,
    this.environmentalCondition,
    this.observerNotes,
    this.submissionDate,
    this.reportCount,
    // Conservation
    this.conservationStatus,
    this.harvestingSeason,
  });
}
