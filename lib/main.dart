import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for the MVP.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await Env.load();

  // Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Firebase + FCM — uncomment after adding google-services.json:
  // try {
  //   await Firebase.initializeApp();
  // } catch (e) {
  //   debugPrint('Firebase init skipped: $e');
  // }

  // PostHog is configured via native meta-data (AndroidManifest / Info.plist).
  // See README §Analytics setup.

  runApp(const ProviderScope(child: ScrollIqApp()));
}

class ScrollIqApp extends ConsumerStatefulWidget {
  const ScrollIqApp({super.key});

  @override
  ConsumerState<ScrollIqApp> createState() => _ScrollIqAppState();
}

class _ScrollIqAppState extends ConsumerState<ScrollIqApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(notificationServiceProvider).init();
      } catch (e) {
        debugPrint('Notification init failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ScrollIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
