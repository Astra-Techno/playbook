import 'dart:async';

/// Delivers API failures to the application shell without coupling the HTTP
/// client to widget context or to an individual feature provider.
class ApiErrorBus {
  ApiErrorBus._();

  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static Stream<String> get messages => _controller.stream;

  static void publish(String message) {
    if (message.trim().isNotEmpty) _controller.add(message);
  }
}
