enum UrlSupport { none, article, feed }

UrlSupport supportFor(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    return UrlSupport.none;
  }
  final lower = raw.toLowerCase();
  if (lower.contains('rss') ||
      lower.contains('/feed') ||
      lower.contains('atom') ||
      lower.endsWith('.xml')) {
    return UrlSupport.feed;
  }
  return UrlSupport.article;
}

String domainOf(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return raw.trim();
  return uri.host.replaceFirst(RegExp(r'^www\.'), '');
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
