import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:stashify/services/stash_service.dart';

final getIt = GetIt.instance;

/// Registers the app's services. Safe to call more than once.
void setupServices() {
  if (getIt.isRegistered<StashService>()) return;

  // One client for the app: it keeps connections alive between writes and
  // the locator closes it.
  if (!getIt.isRegistered<http.Client>()) {
    getIt.registerSingleton<http.Client>(
      http.Client(),
      dispose: (client) => client.close(),
    );
  }

  getIt.registerFactory<StashService>(
    () => StashService(client: getIt<http.Client>()),
  );
}
