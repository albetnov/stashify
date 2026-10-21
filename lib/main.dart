import 'package:fetch_forge/flutter.dart';
import 'package:flutter/material.dart';

import 'package:stashify/screens/home_screen.dart';
import 'package:stashify/services/service_locator.dart';
import 'package:stashify/utils/theme.dart';

void main() {
  setupServices();
  runApp(const StashifyApp());
}

class StashifyApp extends StatefulWidget {
  const StashifyApp({super.key});

  @override
  State<StashifyApp> createState() => _StashifyAppState();
}

class _StashifyAppState extends State<StashifyApp> {
  @override
  void initState() {
    super.initState();
    // Idempotent, and it makes the app work when it is pumped by a widget
    // test, where `main` never runs.
    setupServices();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stashify',
      theme: lightTheme,
      darkTheme: darkTheme,
      home: QueryScope(client: QueryClient(), child: const HomeScreen()),
    );
  }
}
