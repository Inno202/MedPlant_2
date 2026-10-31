class ReportModel {
  final String imageUrl;
  final String location;
  final String date;
  final String environment;
  final String description;

  ReportModel({
    required this.imageUrl,
    required this.location,
    required this.date,
    required this.environment,
    required this.description,
  });

  // 🔥 Convert from Map (Firebase / JSON)
  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      imageUrl: map['image'] ?? '',
      location: map['location'] ?? '',
      date: map['date'] ?? '',
      environment: map['environment'] ?? '',
      description: map['description'] ?? '',
    );
  }

  // 🔥 Convert to Map (for saving)
  Map<String, dynamic> toMap() {
    return {
      'image': imageUrl,
      'location': location,
      'date': date,
      'environment': environment,
      'description': description,
    };
  }
}