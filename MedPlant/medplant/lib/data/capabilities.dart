// lib/data/capabilities.dart
// Aligned with Research Proposal subject descriptors:
// (1) Mobile & ICT tools for biodiversity monitoring
// (2) Indigenous Knowledge Systems
// (3) Machine Learning for plant image analysis
// (4) Community-driven monitoring — Thaba-Nchu, Free State

import '../models/capability.dart';

final List<Capability> coreCapabilities = [
  Capability(
    title: "ML-Powered Plant Identification",
    items: [
      "Random Forest Species ID (Function 1)",
      "TensorFlow Lite on-device inference",
      "Registered Thaba-Nchu species list",
    ],
  ),
  Capability(
    title: "Health Classification & Trends",
    items: [
      "Healthy / Stressed / Degraded rating",
      "Trend-based scoring (Improving / Stable / Declining)",
      "Longitudinal submission history per species",
    ],
  ),
  Capability(
    title: "Damage Detection",
    items: [
      "Leaf discolouration & wilting",
      "Browning, lesions & stem damage",
      "Multi-label detection per submission",
    ],
  ),
  Capability(
    title: "Indigenous Knowledge Integration",
    items: [
      "Barolong community observational indicators",
      "IK-grounded damage detection vocabulary",
      "Traditional healer survey inputs",
    ],
  ),
  Capability(
    title: "Community Reporting",
    items: [
      "Image capture with GPS auto-tagging",
      "Environmental context input",
      "Submission history timeline",
    ],
  ),
  Capability(
    title: "Researcher Analytics Dashboard",
    items: [
      "Longitudinal health trend charts",
      "Species-level degradation alerts",
      "Environmental pattern analysis",
    ],
  ),
];
