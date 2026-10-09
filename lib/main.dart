import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: SketchSyncApp(),
    ),
  );
}

class SketchSyncApp extends StatelessWidget {
  const SketchSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SketchSync',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
