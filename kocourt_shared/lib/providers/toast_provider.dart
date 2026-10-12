import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning }

class ToastItem {
  final String message;
  final ToastType type;
  final String id;

  ToastItem({required this.message, required this.type})
      : id = DateTime.now().millisecondsSinceEpoch.toString();
}

class ToastProvider extends ChangeNotifier {
  final List<ToastItem> _toasts = [];
  List<ToastItem> get toasts => List.unmodifiable(_toasts);

  void show(String message, {ToastType type = ToastType.info}) {
    final toast = ToastItem(message: message, type: type);
    _toasts.add(toast);
    notifyListeners();

    Timer(const Duration(milliseconds: 3500), () {
      _toasts.removeWhere((t) => t.id == toast.id);
      notifyListeners();
    });
  }

  void success(String message) => show(message, type: ToastType.success);
  void error(String message) => show(message, type: ToastType.error);
  void warning(String message) => show(message, type: ToastType.warning);
  void info(String message) => show(message, type: ToastType.info);

  void dismiss(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
