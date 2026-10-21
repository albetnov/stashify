/// The hosts whose articles can be stashed.
///
/// Feeds always work. Articles do not yet: the article parser lands in a
/// later pass, and until it does this list stays empty — so every article
/// reads as unsupported instead of failing halfway through a write.
///
/// Add hosts here when the parser lands. A host covers its subdomains, so
/// `bbc.co.uk` also covers `news.bbc.co.uk`.
const Set<String> supportedArticleHosts = <String>{};
