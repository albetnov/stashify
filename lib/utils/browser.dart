import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Opens [url] in the system in-app browser.
///
/// Custom Tabs carries the page: the shared Chrome session, its own
/// progress, errors, and history. The toolbar takes the scheme's surface
/// so the sheet still belongs to the app. When no in-app browser exists
/// on the device, the failure says so instead of going nowhere.
Future<void> openLivePage(BuildContext context, Uri url) async {
  try {
    if (!await ChromeSafariBrowser.isAvailable()) {
      throw StateError('No in-app browser available.');
    }
    if (!context.mounted) return;
    await ChromeSafariBrowser().open(
      url: WebUri.uri(url),
      settings: ChromeSafariBrowserSettings(
        toolbarBackgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Couldn’t open the live page.')),
      );
  }
}
