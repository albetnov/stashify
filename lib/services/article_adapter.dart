import 'package:stashify/models/article.dart';

/// Thrown when a page has no article an adapter can read.
class ArticleParseException implements Exception {
  const ArticleParseException(this.message);

  /// What to tell the user about the page.
  final String message;

  @override
  String toString() => 'ArticleParseException: $message';
}

/// Turns the HTML of one site into an [Article].
///
/// One adapter per site: the shape of a page is site-specific, so the
/// service picks the adapter that [handles] the host.
abstract interface class ArticleAdapter {
  /// Whether this adapter reads the site [uri] points at.
  bool handles(Uri uri);

  /// Parses [html], fetched from [uri].
  ///
  /// Throws [ArticleParseException] when the page has no readable article.
  Article parse(String html, {required Uri uri});
}
