import 'package:stashify/data/supported_sites.dart';

/// What the app can do with a link.
enum StashSupport {
  /// Not a link.
  none,

  /// A feed — always stashed.
  feed,

  /// An article on a site the parser handles.
  supportedArticle,

  /// An article on a site the parser does not handle.
  unsupportedArticle,
}

/// What [raw] is, and whether it can be stashed.
///
/// Feeds are always stashed. An article is stashed only when its host is in
/// [articleHosts]; [supportedArticleHosts] is the app's list of sites with an
/// adapter.
StashSupport supportFor(
  String raw, {
  Set<String> articleHosts = supportedArticleHosts,
}) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    return StashSupport.none;
  }
  final lower = raw.toLowerCase();
  if (lower.contains('rss') ||
      lower.contains('/feed') ||
      lower.contains('atom') ||
      lower.endsWith('.xml')) {
    return StashSupport.feed;
  }

  final host = domainOf(raw);
  final supported = articleHosts.any(
    (allowed) => host == allowed || host.endsWith('.$allowed'),
  );
  return supported
      ? StashSupport.supportedArticle
      : StashSupport.unsupportedArticle;
}

String domainOf(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return raw.trim();
  return uri.host.replaceFirst(RegExp(r'^www\.'), '');
}

/// Whether [raw] points at a host with an article adapter.
///
/// Unlike [supportFor], this is a host check only: feed-entry links are
/// article links, never stash inputs, so feed-sniffing must not apply.
bool isSupportedArticleHost(
  String raw, {
  Set<String> articleHosts = supportedArticleHosts,
}) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    return false;
  }
  final host = domainOf(raw);
  return articleHosts.any(
    (allowed) => host == allowed || host.endsWith('.$allowed'),
  );
}

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A publish time the way a reader list shows it: relative while the entry
/// is recent, a date once it is not.
String entryTime(DateTime? t) {
  if (t == null) return '';
  if (DateTime.now().difference(t).inDays < 7) return timeAgo(t);
  final day = t.day;
  final month = _months[t.month - 1];
  final year = t.year == DateTime.now().year ? '' : ' ${t.year}';
  return '$day $month$year';
}
