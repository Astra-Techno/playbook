import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          '''Terms of Service

Last updated: August 2026

1. Acceptance of Terms
By using KoCourt, you agree to these Terms of Service. If you do not agree, please do not use our platform.

2. Service Description
KoCourt is a sports venue booking platform that connects players with court owners. We facilitate bookings but do not own or operate venues.

3. User Accounts
You must provide a valid phone number to create an account. You are responsible for maintaining the security of your account.

4. Bookings & Cancellations
Bookings are confirmed instantly upon payment. Cancellation policies are set by individual venue owners. Refunds follow the venue's cancellation policy.

5. Venue Owners
Venue owners are responsible for accuracy of their listings, availability of courts, and quality of facilities.

6. Payments
All payments are processed securely through our payment partners. KoCourt charges a platform fee on each transaction.

7. User Conduct
Users must not misuse the platform, make fraudulent bookings, or engage in harmful behavior.

8. Limitation of Liability
KoCourt is not liable for injuries, disputes between users and venue owners, or venue quality issues.

9. Changes
We may update these terms at any time. Continued use constitutes acceptance.

10. Contact
For questions, contact us at legal@kocourt.com.''',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
        ),
      ),
    );
  }
}
