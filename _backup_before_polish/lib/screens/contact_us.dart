import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/widgets/section_header.dart';
import '../constants/app_colors.dart';
import '../models/contact_us_model.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Update the dummyContact with user input
      dummyContact.name = nameController.text.trim();
      dummyContact.email = emailController.text.trim();
      dummyContact.subject = subjectController.text.trim();
      dummyContact.message = messageController.text.trim();

      // Here you could send to Firestore, API, etc.
      print('Contact submitted:');
      print('Name: ${dummyContact.name}');
      print('Email: ${dummyContact.email}');
      print('Subject: ${dummyContact.subject}');
      print('Message: ${dummyContact.message}');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = dummyContact;

    Widget _detailCard(IconData icon, String title, String value) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Contact ITIKI Africa'),
      //   backgroundColor: AppColors.primaryDark,
      //   centerTitle: true,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            // Row(
            //   children: const [
            //     Icon(FontAwesomeIcons.envelope, color: AppColors.primarySoft),
            //     SizedBox(width: 8),
            //     Text(
            //       'Contact ITIKI Africa',
            //       style: TextStyle(
            //           fontSize: 20,
            //           fontWeight: FontWeight.w700,
            //           color: AppColors.primaryDark),
            //     ),
            //   ],
            // ),
            SectionHeader(title: "Contact Us"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & intro
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.paperPlane,
                          color: AppColors.primarySoft, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.title,
                                style: GoogleFonts.montserrat(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark)),
                            Text(contact.subtitle,
                                style: GoogleFonts.dancingScript(
                                    fontSize: 16,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(contact.intro,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 24),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              hintText: 'Your full name',
                              filled: true,
                              fillColor: Color(0xFFFAFDFB),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              )),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                              hintText: 'your.email@example.com',
                              filled: true,
                              fillColor: Color(0xFFFAFDFB),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              )),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter your email' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: subjectController,
                          decoration: const InputDecoration(
                              hintText: 'Subject',
                              filled: true,
                              fillColor: Color(0xFFFAFDFB),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              )),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter a subject' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: messageController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                              hintText:
                                  'Your message (minimum 200 characters, no links)',
                              filled: true,
                              fillColor: Color(0xFFFAFDFB),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              )),
                          validator: (value) => value!.length < 200
                              ? 'Message must be at least 200 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                                onPressed: _submitForm,
                                icon:
                                    const FaIcon(FontAwesomeIcons.paperPlane, color: AppColors.white),
                                label:  Text('Send message', style: GoogleFonts.lato(color: AppColors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(40)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                )),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                _formKey.currentState!.reset();
                                nameController.clear();
                                emailController.clear();
                                subjectController.clear();
                                messageController.clear();
                              },
                              icon: const FaIcon(FontAwesomeIcons.times,  color: AppColors.primaryDark),
                              label:  Text('Cancel', style: GoogleFonts.lato(color: AppColors.primaryDark) ,),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.primaryDark, width: 2),
                                foregroundColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Contact info cards
                  _detailCard(FontAwesomeIcons.phoneAlt, 'Phone', contact.phone),
                  _detailCard(FontAwesomeIcons.envelope, 'Email', contact.contactEmail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}