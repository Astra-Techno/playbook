import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/toast_provider.dart';

/// Convenience toast helpers so screens never need ScaffoldMessenger SnackBars.
extension AppFeedback on BuildContext {
  ToastProvider get _toasts => read<ToastProvider>();

  void toastSuccess(String message) => _toasts.success(message);
  void toastError(String message) => _toasts.error(message);
  void toastWarning(String message) => _toasts.warning(message);
  void toastInfo(String message) => _toasts.info(message);
}
