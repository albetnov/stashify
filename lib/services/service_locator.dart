import 'package:fetch_forge/fetch_forge.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:stashify/services/stash_service.dart';

final getIt = GetIt.instance;

/// Registers the app's services. Safe to call more than once.
void setupServices() {
  // One query cache for the app: entry queries share it, so two rows for
  // the same link run one fetch. The scope never disposes it.
  if (!getIt.isRegistered<QueryClient>()) {
    getIt.registerSingleton<QueryClient>(
      QueryClient(),
      dispose: (client) => client.dispose(),
    );
  }

  // One client for the app: it keeps connections alive between writes and
  // the locator closes it.
  if (!getIt.isRegistered<http.Client>()) {
    getIt.registerSingleton<http.Client>(
      http.Client(),
      dispose: (client) => client.close(),
    );
  }

  if (getIt.isRegistered<StashService>()) return;

  getIt.registerFactory<StashService>(
    () => StashService(client: getIt<http.Client>()),
  );
}

/// Async entry point for app startup.
///
/// Registers everything [setupServices] does, then opens the database,
/// migrates it, and preloads the library. The store is in-memory for now,
/// so this only yields to let the splash paint; the persistence steps slot
/// in here without touching the UI.
///
/// [offline] skips persistence once it lands: the app runs memory-only for
/// the session.
Future<void> setupServicesAsync({bool offline = false}) async {
  setupServices();
  if (!offline) {
    // Database open, migrate, and preload land here.
  }
  // Yield so the splash paints at least one frame before home.
  await Future<void>.delayed(Duration.zero);
}
