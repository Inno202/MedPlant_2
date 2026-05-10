import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactModel {
  String name;
  String email;
  String subject;
  String message;

  final String title;
  final String subtitle;
  final String intro;
  final String phone;
  final String contactEmail;
  final List<Map<String, dynamic>> badges;

  ContactModel({
    this.name = '',
    this.email = '',
    this.subject = '',
    this.message = '',
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.phone,
    required this.contactEmail,
    required this.badges,
  });
}

// Dummy instance mimicking website content
final ContactModel dummyContact = ContactModel(
  title: 'Reach out',
  subtitle: '... we\'d love to hear ...',
  intro:
      'For collaboration, research partnerships, or general enquiries — drop us a message.',
  phone: '+254 (0) 700 000 000',
  contactEmail: 'info@itiki.africa',
  badges: [
    {'icon': FontAwesomeIcons.handshake, 'text': 'Collaboration'},
    {'icon': FontAwesomeIcons.flask, 'text': 'Research'},
    {'icon': FontAwesomeIcons.globe, 'text': 'Partnerships'},
    {'icon': FontAwesomeIcons.leaf, 'text': 'Conservation'},
    {'icon': FontAwesomeIcons.comment, 'text': 'General enquiry'},
  ],
);