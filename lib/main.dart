import 'package:fetch_forge/flutter.dart';
import 'package:flutter/material.dart';

import 'package:stashify/screens/home_screen.dart';
import 'package:stashify/services/service_locator.dart';
import 'package:stashify/utils/theme.dart';
import 'package:stashify/widgets/splash_screen.dart';

void main() {
  runApp(const StashifyApp());
}

class StashifyApp extends StatefulWidget {
  const StashifyApp({super.key, this.initServices = setupServicesAsync});

  /// Runs the async startup the splash gates on. A hook rather than a
  /// direct call so widget tests can answer slowly or fail on purpose
  /// without touching real services.
  final Future<void> Function({bool offline}) initServices;

  @override
  State<StashifyApp> createState() => _StashifyAppState();
}

class _StashifyAppState extends State<StashifyApp> {
  late Future<void> _init = widget.initServices();

  void _retry() {
    setState(() {
      _init = widget.initServices();
    });
  }

  void _continueOffline() {
    setState(() {
      _init = widget.initServices(offline: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stashify',
      theme: lightTheme,
      darkTheme: darkTheme,
      home: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return InitErrorScreen(
              onRetry: _retry,
              onContinueOffline: _continueOffline,
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }
          return QueryScope(
            client: getIt<QueryClient>(),
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}
