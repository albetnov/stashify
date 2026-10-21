/// The hosts whose articles can be stashed.
///
/// Feeds always work. An article works only on a site with an adapter, so
/// add its host here when the adapter lands. A host covers its subdomains,
/// so `bbc.co.uk` also covers `news.bbc.co.uk`.
const Set<String> supportedArticleHosts = <String>{'albetnv.dev'};
