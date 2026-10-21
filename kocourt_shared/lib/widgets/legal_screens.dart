import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class RefundCancellationScreen extends StatelessWidget {
  const RefundCancellationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Refund & Cancellation', style: TextStyle(fontWeight: FontWeight.w800))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Last updated: 16 October 2026', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 20),
              _Callout(
                icon: Icons.schedule_rounded,
                title: '24-hour cancellation window',
                body: 'Cancel at least 24 hours before your scheduled slot to receive a full refund.',
              ),
              const SizedBox(height: 24),
              const _LegalSection(title: 'Eligible cancellations', body: 'A booking cancelled at least 24 hours before its scheduled start time is eligible for a full refund. Cancel from My Bookings. Refunds are returned to the original payment method; KoCourt does not issue cash refunds.'),
              const _LegalSection(title: 'Cancellations within 24 hours', body: 'A booking cancelled less than 24 hours before its scheduled start time is non-refundable.'),
              const _LegalSection(title: 'Venue or technical cancellations', body: 'If a venue cancels a confirmed booking, or a paid booking cannot be confirmed because of a technical error, you are eligible for a full refund.'),
              const _LegalSection(title: 'Refund timing', body: 'After an eligible refund is approved, it is initiated to the original payment method. Banks, card networks, and UPI providers may take 5–7 business days to reflect the amount.'),
              const _LegalSection(title: 'Memberships and plans', body: 'Membership or subscription payments are non-refundable once the plan period has started, unless required by applicable law.'),
              _SupportCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen()))),
            ],
          ),
        ),
      );
}

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Contact KoCourt', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.darkGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.headset_mic_rounded, size: 28, color: AppColors.accent),
                  SizedBox(height: 14),
                  Text('We are here to help', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  SizedBox(height: 6),
                  Text('For booking, payment, cancellation, or account support, contact us using either channel below.', style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFD1D5DB))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ContactTile(icon: Icons.phone_outlined, label: 'Call support', value: '+91 99944 39081', onTap: () => _copy(context, '+919994439081', 'Support number')),
            const SizedBox(height: 12),
            _ContactTile(icon: Icons.email_outlined, label: 'Email support', value: 'support@kocourt.com', onTap: () => _copy(context, 'support@kocourt.com', 'Support email')),
            const SizedBox(height: 16),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('For a booking or payment issue, include your registered phone number and booking ID.', style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary))),
          ],
        ),
      );
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;
  const _LegalSection({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.textSecondary)),
        ]),
      );
}

class _Callout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Callout({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primary.withValues(alpha: 0.16))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _SupportCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SupportCard({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: const Row(children: [
            Icon(Icons.support_agent_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(child: Text('Need help with a refund?', style: TextStyle(fontWeight: FontWeight.w800))),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        ),
      );
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ContactTile({required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(icon, color: AppColors.primary)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.textMuted)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ])),
            const Icon(Icons.copy_outlined, size: 18, color: AppColors.textMuted),
          ]),
        ),
      );
}
