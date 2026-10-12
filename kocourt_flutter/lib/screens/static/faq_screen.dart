import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = [
    {'q': 'How do I book a court?', 'a': 'Browse venues on the home screen, select a court, pick your date and time slot, then confirm your booking.'},
    {'q': 'Can I cancel a booking?', 'a': 'Yes, go to My Bookings, tap the booking you want to cancel, and hit Cancel. Cancellation is free if done 2+ hours before the slot.'},
    {'q': 'How do memberships work?', 'a': 'Venue owners can create subscription plans. Subscribe to get priority access and discounted rates during peak hours.'},
    {'q': 'How do I list my venue?', 'a': 'Switch to owner mode from your profile, then tap "Add Venue" to list your sports facility on KoCourt.'},
    {'q': 'What payment methods are accepted?', 'a': 'We support UPI, credit/debit cards, and net banking through our payment partner.'},
    {'q': 'How do I contact support?', 'a': 'Reach us at support@kocourt.com or through the in-app feedback option in your profile.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('FAQ', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _faqs.length,
        itemBuilder: (_, i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(_faqs[i]['q']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              children: [Text(_faqs[i]['a']!, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5))],
            ),
          );
        },
      ),
    );
  }
}
