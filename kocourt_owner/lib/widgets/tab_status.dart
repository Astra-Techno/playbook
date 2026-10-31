import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class TabErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const TabErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not refresh',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 4),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class TabEmptyMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const TabEmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ],
    );
  }
}
