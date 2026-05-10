class ObservationModel {
  final String observerName;
  final String date;
  final String location;
  final String temperature;
  final String description;
  final String imageUrl;

  ObservationModel({
    required this.observerName,
    required this.date,
    required this.location,
    required this.temperature,
    required this.description,
    required this.imageUrl,
  });
}