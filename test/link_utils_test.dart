// What a link is, and whether it can be stashed.
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/utils/link_utils.dart';

void main() {
  test('a feed link is always supported', () {
    expect(supportFor('https://example.com/feed.xml'), StashSupport.feed);
    expect(supportFor('https://news.site.com/rss'), StashSupport.feed);
    expect(supportFor('https://site.com/atom'), StashSupport.feed);
  });

  test('an article on an unknown site is not supported', () {
    expect(
      supportFor('https://example.com/some/article'),
      StashSupport.unsupportedArticle,
    );
  });

  test('an article on a supported site is supported', () {
    expect(
      supportFor(
        'https://bbc.co.uk/news/story',
        articleHosts: {'bbc.co.uk'},
      ),
      StashSupport.supportedArticle,
    );
  });

  test('a supported host covers its subdomains', () {
    expect(
      supportFor(
        'https://news.bbc.co.uk/story',
        articleHosts: {'bbc.co.uk'},
      ),
      StashSupport.supportedArticle,
    );
  });

  test('a lookalike host is not a supported host', () {
    expect(
      supportFor(
        'https://evil-bbc.co.uk/story',
        articleHosts: {'bbc.co.uk'},
      ),
      StashSupport.unsupportedArticle,
    );
  });

  test('nonsense is not a link', () {
    expect(supportFor('not a url'), StashSupport.none);
    expect(supportFor('ftp://example.com/file'), StashSupport.none);
    expect(supportFor(''), StashSupport.none);
  });

  test('an article on albetnv.dev is supported', () {
    expect(
      supportFor('https://albetnv.dev/blog/story'),
      StashSupport.supportedArticle,
    );
  });

  test('a site without an adapter is not supported', () {
    expect(supportFor('https://example.com/some/article'),
        StashSupport.unsupportedArticle);
  });
}
