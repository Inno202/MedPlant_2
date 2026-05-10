// lib/models/user_role.dart
// Aligned with research proposal ERD (Assignment 3, Section 2.5)
// Two actors only: Community User (IK holder) and Researcher

enum UserRole {
  /// Traditional healers and community members in Thaba-Nchu.
  /// Primary data contributors — submit image-based plant reports.
  communityUser,

  /// Researcher / study supervisor.
  /// Manages species register, reviews flagged submissions,
  /// monitors analytics dashboard and degradation alerts.
  researcher,
}
