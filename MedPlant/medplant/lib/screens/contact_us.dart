import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/contact_us_model.dart';
import '../providers/user_provider.dart';
import '../widgets/secondary_scaffold.dart';

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

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name/email for logged-in users.
    final user = context.read<UserProvider>();
    nameController.text = user.username ?? '';
    emailController.text = user.email ?? '';
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _clear() {
    _formKey.currentState?.reset();
    subjectController.clear();
    messageController.clear();
  }

  /// Saves the message to Firestore (`contact_messages`), where
  /// researchers read it on the Contact Messages screen. Previously the
  /// form only printed to the debug console.
  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'subject': subjectController.text.trim(),
        'message': messageController.text.trim(),
        'uid': context.read<UserProvider>().uid,
        'read': false,
        'sentAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Message sent — thank you! We'll get back to you soon."),
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't send your message. Please try again."),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.primarySoft),
        filled: true,
        fillColor: const Color(0xFFFAFDFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

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

    return SecondaryScaffold(
      title: 'Contact Us',
      maxWidth: 700,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Container(
          padding: const EdgeInsets.all(20),
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
                children: [
                  const Icon(FontAwesomeIcons.paperPlane,
                      color: AppColors.primarySoft, size: 20),
                  const SizedBox(width: 10),
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
                                fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(contact.intro,
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: AppColors.textPrimary)),
              const SizedBox(height: 20),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Your full name', Icons.person),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                          'your.email@example.com', Icons.email_outlined),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Please enter your email';
                        if (!_emailPattern.hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subjectController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration('Subject', Icons.subject),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a subject'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageController,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                          'Your message', Icons.chat_bubble_outline),
                      validator: (v) => (v == null || v.trim().length < 20)
                          ? 'Please write at least 20 characters'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _submitForm,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const FaIcon(FontAwesomeIcons.paperPlane,
                                size: 16, color: AppColors.white),
                        label: Text(_sending ? 'Sending…' : 'Send message',
                            style: GoogleFonts.lato(
                                color: AppColors.white, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          disabledBackgroundColor:
                              AppColors.primaryDark.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _clear,
                        icon: const Icon(Icons.refresh,
                            size: 18, color: AppColors.primaryDark),
                        label: Text('Clear',
                            style: GoogleFonts.lato(
                                color: AppColors.primaryDark, fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primaryDark, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _detailCard(FontAwesomeIcons.phone, 'Phone', contact.phone),
              _detailCard(
                  FontAwesomeIcons.envelope, 'Email', contact.contactEmail),
            ],
          ),
        ),
      ),
    );
  }
}
