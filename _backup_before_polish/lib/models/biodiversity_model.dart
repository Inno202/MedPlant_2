import 'package:flutter/material.dart';

class BiodiversityModel {
  final String title;
  final String region;
  final double healthIndex;
  final String status;
  final String threatLevel;
  final String conservationPriority;
  final int reportsThisMonth;

  // 🔥 icons for UI reuse
  final IconData mainIcon;
  final IconData healthIcon;
  final IconData threatIcon;
  final IconData priorityIcon;
  final IconData reportsIcon;

  BiodiversityModel({
    required this.title,
    required this.region,
    required this.healthIndex,
    required this.status,
    required this.threatLevel,
    required this.conservationPriority,
    required this.reportsThisMonth,
    required this.mainIcon,
    required this.healthIcon,
    required this.threatIcon,
    required this.priorityIcon,
    required this.reportsIcon,
  });
}