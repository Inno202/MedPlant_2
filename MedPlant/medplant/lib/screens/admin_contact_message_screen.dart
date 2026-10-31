// lib/screens/admin_contact_message_screen.dart
// Researcher view of messages sent from the Contact Us form
// (Firestore collection `contact_messages`, newest first).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../widgets/secondary_scaffold.dart';

class AdminContactMessagesScreen extends StatefulWidget {
  const AdminContactMessagesScreen({super.key});

  @override
  State<AdminContactMessagesScreen> createState() =>
      _AdminContactMessagesScreenState();
}

class _AdminContactMessagesScreenState
    extends State<AdminContactMessagesScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('contact_messages').snapshots();

  static String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} · $hh:$mm';
  }

  Future<void> _markRead(DocumentReference ref, bool read) async {
    try {
      await ref.update({'read': read});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update the message.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryScaffold(
      title: 'Contact Messages',
      maxWidth: 800,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _Info(
              icon: Icons.cloud_off,
              title: "Couldn't load messages",
              text: "Please check your connection and try again.",
            );
          }

          // Sorted client-side so no Firestore index is needed.
          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final at = a.data()['sentAt'];
            final bt = b.data()['sentAt'];
            if (at is! Timestamp) return 1;
            if (bt is! Timestamp) return -1;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const _Info(
              icon: Icons.mark_email_read_outlined,
              title: "No messages yet",
              text: "Messages sent from the Contact Us page will appear here.",
            );
          }

          final unread = docs.where((d) => d.data()['read'] != true).length;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "${docs.length} message${docs.length == 1 ? '' : 's'} · $unread unread",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                );
              }
              final doc = docs[i - 1];
              return _MessageCard(
                data: doc.data(),
                date: _formatDate(doc.data()['sentAt']),
                onToggleRead: (read) => _markRead(doc.reference, read),
              );
            },
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String date;
  final ValueChanged<bool> onToggleRead;

  const _MessageCard({
    required this.data,
    required this.date,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final read = data['read'] == true;
    final name = (data['name'] as String?)?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: read ? AppColors.borderSoft : AppColors.primarySoft,
          width: read ? 1 : 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          onExpansionChanged: (open) {
            if (open && !read) onToggleRead(true);
          },
          leading: CircleAvatar(
            backgroundColor:
                read ? AppColors.accentBg : AppColors.primary,
            child: Text(
              (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
              style: TextStyle(
                color: read ? AppColors.primaryDark : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            data['subject'] ?? '(no subject)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: read ? FontWeight.w600 : FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          subtitle: Text(
            [name ?? 'Unknown', if (date.isNotEmpty) date].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                data['email'] ?? '',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                data['message'] ?? '',
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textPrimary),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onToggleRead(!read),
                icon: Icon(read ? Icons.mark_email_unread : Icons.done_all,
                    size: 16),
                label: Text(read ? 'Mark unread' : 'Mark read'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Info({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primarySoft),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
