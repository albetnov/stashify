import 'dart:io';

import 'package:fetch_forge/fetch_forge.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_driver_forge/sqlite3_driver_forge.dart';

import 'package:stashify/services/stash_service.dart';

final getIt = GetIt.instance;

/// Opens the app database, creating the file on first launch.
///
/// The connection lives on the driver's worker isolate: the UI thread
/// never touches SQLite directly.
Future<SqliteDriver> openAppDatabase({Directory? directory}) async {
  final dir = directory ?? await _appDbDir();
  final driver = SqliteDriver.file(p.join(dir.path, 'stashify.db'));
  await driver.connect();
  return driver;
}

/// Where the database file lives.
///
/// Tests run without platform plugins: plain unit tests have no binding at
/// all ([StateError]) and widget tests have no method channels
/// ([MissingPluginException]). Either way fall back to a temp dir so the
/// app still boots. Production always has path_provider — anything else
/// failing still surfaces as a startup error.
Future<Directory> _appDbDir() async {
  try {
    return await getApplicationDocumentsDirectory();
  } on MissingPluginException {
    return Directory.systemTemp.createTemp('stashify.');
  } on StateError {
    return Directory.systemTemp.createTemp('stashify.');
  }
}

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

  // One database connection for the app, opened on first use. The locator
  // closes it.
  if (!getIt.isRegistered<SqliteDriver>()) {
    getIt.registerSingletonAsync<SqliteDriver>(
      openAppDatabase,
      dispose: (driver) => driver.disconnect(),
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
/// migrates it, and preloads the library. Migration and preload still
/// land here; the connection already opens today.
///
/// [offline] skips persistence: the app runs memory-only for the session.
Future<void> setupServicesAsync({bool offline = false}) async {
  setupServices();
  if (!offline) {
    // Opens the database file, creating it on first launch. Failures
    // surface through the splash gate.
    await getIt.getAsync<SqliteDriver>();
    // Migrate and preload land here.
  }
  // Yield so the splash paints at least one frame before home.
  await Future<void>.delayed(Duration.zero);
}
