import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_error_bus.dart';
import '../core/theme.dart';
import '../providers/toast_provider.dart';

class ToastOverlay extends StatefulWidget {
  final Widget child;
  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  StreamSubscription<String>? _apiErrorSubscription;

  @override
  void initState() {
    super.initState();
    _apiErrorSubscription = ApiErrorBus.messages.listen((message) {
      if (mounted) context.read<ToastProvider>().error(message);
    });
  }

  @override
  void dispose() {
    _apiErrorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          // Sits above the Navigator, so it needs its own Material for text style and ink.
          child: Material(
            type: MaterialType.transparency,
            child: Consumer<ToastProvider>(
              builder: (_, toasts, __) {
                return Column(
                  children: toasts.toasts.map((toast) {
                    return _ToastCard(key: ValueKey(toast.id), toast: toast);
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatefulWidget {
  final ToastItem toast;
  const _ToastCard({super.key, required this.toast});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (widget.toast.type) {
      ToastType.success => AppColors.secondary,
      ToastType.error => AppColors.error,
      ToastType.warning => AppColors.warning,
      ToastType.info => AppColors.info,
    };
    final well = switch (widget.toast.type) {
      ToastType.success => AppColors.successLight,
      ToastType.error => AppColors.errorLight,
      ToastType.warning => AppColors.warningLight,
      ToastType.info => AppColors.infoLight,
    };
    final icon = switch (widget.toast.type) {
      ToastType.success => Icons.check_circle_rounded,
      ToastType.error => Icons.error_rounded,
      ToastType.warning => Icons.warning_amber_rounded,
      ToastType.info => Icons.info_rounded,
    };

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.elevated,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: well,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(icon, color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.toast.message,
                              style: TextStyle(
                                color: context.brand.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context.read<ToastProvider>().dismiss(widget.toast.id),
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
