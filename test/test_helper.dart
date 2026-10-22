// Shared widget-test setup.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String? _pathProviderDir;

/// Serves path_provider from a temp dir.
///
/// Widget tests have no platform plugins, and an unmocked path_provider
/// channel never answers (it hangs instead of throwing), which would stall
/// app startup on the splash forever. Call from setUp in any test that
/// pumps the app with the real init.
void mockPathProvider() {
  _pathProviderDir ??=
      Directory.systemTemp.createTempSync('stashify-test.').path;
  final dir = _pathProviderDir!;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return dir;
          }
          return null;
        },
      );
}
