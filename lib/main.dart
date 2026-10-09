import 'package:flutter/material.dart';

import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  runApp(const SketchSyncApp());
}

class SketchSyncApp extends StatelessWidget {
  const SketchSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SketchSync',
      theme: AppTheme.lightTheme,
      home: const SketchSyncHome(),
    );
  }
}

class SketchSyncHome extends StatelessWidget {
  const SketchSyncHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'SketchSync ',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
