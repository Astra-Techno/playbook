import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'providers/venue_provider.dart';
import 'providers/toast_provider.dart';
import 'providers/notifications_provider.dart';
import 'widgets/toast_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Api().init();

  final authProvider = AuthProvider()..init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => VenueProvider()),
        ChangeNotifierProvider(create: (_) => ToastProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: KoCourtApp(authProvider: authProvider),
    ),
  );
}

class KoCourtApp extends StatefulWidget {
  final AuthProvider authProvider;
  const KoCourtApp({super.key, required this.authProvider});

  @override
  State<KoCourtApp> createState() => _KoCourtAppState();
}

class _KoCourtAppState extends State<KoCourtApp> {
  late final _router = createRouter(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KoCourt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
      builder: (context, child) {
        return ToastOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
