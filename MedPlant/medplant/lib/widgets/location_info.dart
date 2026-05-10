import 'package:flutter/material.dart';

class LocationInfo extends StatelessWidget {
  final String status;

  const LocationInfo({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on),
          const SizedBox(width: 8),
          Expanded(child: Text(status)),
        ],
      ),
    );
  }
}