import 'package:flutter/material.dart';

void main() {
  runApp(const SketchSyncApp());
}

class SketchSyncApp extends StatelessWidget {
  const SketchSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SketchSync',
      home: Scaffold(
        body: Center(
          child: Text(
            'SketchSync ✨',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
