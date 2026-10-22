// A feed to parse in the tests, and a client that serves it.
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fetch_forge/fetch_forge.dart';
import 'package:stashify/services/stash_service.dart';

const feedXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Stashify Weekly</title>
    <link>https://example.com</link>
    <description>Notes for the offline commute</description>
    <item>
      <title>Reading on the train</title>
      <link>https://example.com/reading-on-the-train</link>
      <description>Why offline still wins</description>
      <pubDate>Mon, 05 Oct 2020 12:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Second entry</title>
      <link>https://example.com/second</link>
    </item>
  </channel>
</rss>
''';

const pageHtml = '''
<!DOCTYPE html>
<html><head><title>A page</title></head><body>Not a feed.</body></html>
''';

/// A service that serves [body] for every request.
StashService serviceServing(
  String body, {
  int status = 200,
  Duration delay = Duration.zero,
  QueryClient? queryClient,
}) {
  return StashService(
    client: MockClient((request) async {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return http.Response(
        body,
        status,
        headers: {'content-type': 'application/rss+xml; charset=utf-8'},
      );
    }),
    queryClient: queryClient,
  );
}
