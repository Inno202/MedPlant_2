class AboutModel {
  final String title;
  final String subtitle; // "...the ITIKI way..."
  final String description1;
  final String description2;
  final String highlight;
  final String extraText;
  final String itikiLink;

  AboutModel({
    required this.title,
    required this.subtitle,
    required this.description1,
    required this.description2,
    required this.highlight,
    required this.extraText,
    required this.itikiLink,
  });

  factory AboutModel.fromMap(Map<String, dynamic> map) {
    return AboutModel(
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      description1: map['description1'] ?? '',
      description2: map['description2'] ?? '',
      highlight: map['highlight'] ?? '',
      extraText: map['extraText'] ?? '',
      itikiLink: map['itikiLink'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'description1': description1,
      'description2': description2,
      'highlight': highlight,
      'extraText': extraText,
      'itikiLink': itikiLink,
    };
  }
}

/// ✅ Dummy data from your HTML
final AboutModel dummyAbout = AboutModel(
  title: "Integrating indigenous knowledge & ICT",
  subtitle: "... the ITIKI way ...",

  description1:
      "MedPlants is a platform that integrates indigenous knowledge and ICT tools to monitor medicinal plants. The platform allows users to report their observations of medicinal plants, including details such as the observation location, environmental conditions, and a description of the observation.",

  description2:
      "The platform also provides information about different medicinal plant species, including their scientific and common names, and images. MedPlants aims to promote the conservation and sustainable use of medicinal plants by providing a platform for sharing knowledge and monitoring plant populations.",

  highlight:
      "The platform is designed to be user-friendly and accessible to a wide range of users, including field managers, researchers, and the general public. By leveraging indigenous knowledge and ICT tools, MedPlants seeks to empower communities to take an active role in the conservation and sustainable use of medicinal plants.",

  extraText:
      "MedPlants is a collaborative effort that brings together experts in the fields of botany, ecology, and information technology. The platform is continuously being developed and improved to better serve the needs of its users and to contribute to the conservation of medicinal plants.\n\nThis project is part of the ITIKI initiative. For more information about the ITIKI platform and its features, please visit the ITIKI website.",

  itikiLink: "https://itiki.africa/",
);