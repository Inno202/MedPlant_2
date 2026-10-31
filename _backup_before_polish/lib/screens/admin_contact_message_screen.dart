import 'package:flutter/material.dart';
import 'package:medplant/models/contact_us_model.dart';
import 'package:medplant/widgets/section_header.dart';
import '../constants/app_colors.dart';

class AdminContactMessagesScreen extends StatelessWidget {
  final List<ContactModel> messages;

  const AdminContactMessagesScreen({super.key, required this.messages});

  Widget _detailCard(ContactModel message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name & Email
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                '${message.name} (${message.email})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject
          Row(
            children: [
              Icon(Icons.subject, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                message.subject,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Message Body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.message, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.message,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: "Contact Messages"),
            const SizedBox(height: 16),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text('No messages yet.'),
                    )
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _detailCard(messages[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}