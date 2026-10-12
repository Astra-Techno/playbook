import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Api().init();

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => VenueProvider()),
        ChangeNotifierProvider(create: (_) => ToastProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: KoCourtOwnerApp(authProvider: authProvider),
    ),
  );
}

class KoCourtOwnerApp extends StatefulWidget {
  final AuthProvider authProvider;
  const KoCourtOwnerApp({super.key, required this.authProvider});

  @override
  State<KoCourtOwnerApp> createState() => _KoCourtOwnerAppState();
}

class _KoCourtOwnerAppState extends State<KoCourtOwnerApp> {
  late final _router = createOwnerRouter(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KoCourt Owner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
      builder: (context, child) {
        return ToastOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
