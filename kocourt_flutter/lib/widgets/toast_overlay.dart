import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/toast_provider.dart';

class ToastOverlay extends StatelessWidget {
  final Widget child;
  const ToastOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Consumer<ToastProvider>(
            builder: (_, toasts, __) {
              return Column(
                children: toasts.toasts.map((toast) {
                  return _ToastCard(toast: toast);
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastItem toast;
  const _ToastCard({required this.toast});

  @override
  Widget build(BuildContext context) {
    final color = switch (toast.type) {
      ToastType.success => AppColors.secondary,
      ToastType.error => AppColors.error,
      ToastType.warning => AppColors.warning,
      ToastType.info => AppColors.info,
    };
    final icon = switch (toast.type) {
      ToastType.success => Icons.check_circle_rounded,
      ToastType.error => Icons.error_rounded,
      ToastType.warning => Icons.warning_rounded,
      ToastType.info => Icons.info_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.elevated,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              toast.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<ToastProvider>().dismiss(toast.id),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
