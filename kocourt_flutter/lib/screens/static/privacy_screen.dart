import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          '''Privacy Policy

Last updated: August 2026

1. Information We Collect
We collect your phone number, name, location data, and booking history to provide our services.

2. How We Use Your Information
- To process bookings and payments
- To show nearby venues based on your location
- To send booking confirmations and reminders
- To improve our platform

3. Data Sharing
We share relevant booking details with venue owners. We do not sell your personal data to third parties.

4. Location Data
We use your GPS location to show nearby courts. You can disable location access in your device settings.

5. Data Security
We use industry-standard encryption and security measures to protect your data.

6. Data Retention
We retain your data as long as your account is active. You can request deletion by contacting us.

7. Your Rights
You have the right to access, correct, or delete your personal data. Contact us at privacy@kocourt.com.

8. Changes
We may update this policy. We will notify you of significant changes.

9. Contact
For privacy concerns, contact us at privacy@kocourt.com.''',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
        ),
      ),
    );
  }
}
