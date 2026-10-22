import 'package:flutter/material.dart';

/// The launch splash: shown while services initialise (database open,
/// migration, first load).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.offline_pin_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Stashify', style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Getting your library ready…',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dead end when service initialisation fails.
///
/// Nothing is lost: the stash stays on disk. Retry runs the whole init
/// again; continuing without saving runs the app memory-only for this
/// session.
class InitErrorScreen extends StatelessWidget {
  const InitErrorScreen({
    super.key,
    required this.onRetry,
    required this.onContinueOffline,
  });

  final VoidCallback onRetry;
  final VoidCallback onContinueOffline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 12),
                  Text("Couldn't open your library", style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Your saved items are still on this device. '
                    'Check storage and try again.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onContinueOffline,
                    child: const Text('Continue without saving'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
