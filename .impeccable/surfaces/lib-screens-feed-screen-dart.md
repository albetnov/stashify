---
version: 1
slug: "lib-screens-feed-screen-dart"
primary_target: "lib/screens/feed_screen.dart"
related_targets: ["lib/widgets/feed_entry_row.dart","lib/services/stash_service.dart"]
---

# Feed entries screen

## Scope

A new route in Stashify (Android, Flutter). It lists the entries of a stashed
feed, each with a Read action. Visitor mode: Operate — the visitor arrived to
find something to read offline and is scanning a list to choose it.

- Audience: the offline commuter with a feed already in the stash.
- Job: scan the feed's entries and start reading one.
- Action: tap Read on an entry.
- Content: real entry titles, publish times and summaries, parsed from the
  stashed feed.
- Constraints: everything is in memory for now (no persistence yet); entry
  bodies are cached on the feed itself, so downloading one adds nothing to
  the library.
- Unresolved: read/unread state is out of scope (PRODUCT.md leaves it
  undecided).

## Direction contract

THESIS: A stashed feed is only useful if its contents are legible. The screen
exists to let the visitor pick one entry to read, so the entries are the
screen and the chrome is one line. It refuses the subscription-dashboard
arrangement — no folders, no unread counters, no feed chrome — because the
stash is a shelf of things to read, not an inbox. One control per entry:
Read downloads a readable entry on first tap and opens it after, opens a
cached entry at once with the offline mark beside it, and an entry with no
readable link honestly says Not supported instead of Read.

OWN-WORLD: The app's settled world: the green-seeded Material 3 scheme
(#0B6B4F), surfaceContainerHigh cards in the library, the M3 type scale
(titleMedium titles, bodySmall and bodyMedium muted meta), 12–16px radii,
hairline dividers, and the offline-pin motif. The screen inherits that
scheme, that type scale, and the library's rhythm of a title followed by a
muted meta line; muted text stays tinted from the scheme, never gray. No new
palette, no new face, no new shape language.

STORY: The visitor stashed a feed; tapping it opens the entries it holds,
newest first. Each entry shows what it is (title), when it was published,
and enough of itself (a two-line summary) to recognise it without opening
it. One control per entry starts reading it. The visitor leaves knowing:
this feed is in my stash, this is what is in it, and reading is one tap away.

FIRST VIEWPORT: The app bar carries the feed's identity — its title in the
title slot, and a line "31 entries · feeds.bbci.co.uk" beneath it, the bar
growing with the text so a large font scale never clips it. Below that, the
list begins almost immediately: the app bar is the only chrome. Each entry is
a hairline-divided block, not a card: the title (titleMedium, two lines)
with the summary tight under it (bodyMedium, muted, two lines), then a footer
line carrying the publish time (bodySmall, muted) on the left and a "Read"
text button trailing on the right, its label ending where the rule above it
ends. The first entry sits ~8px under the app bar.

FORM: An extension of the home screen's list composition — the same
title-then-muted-meta rhythm, with the app bar inheriting the identity the
library row used to carry. The structure is a flat hairline-divided list of
entries rather than cards: 31 entries is a list, not a gallery.
seed:67d38e3b4dfe177e

FINISH: unreviewed and undocumented is unfinished; this build ends with the
finish review, the verdict, DESIGN.md, and every shipping raster carrying
its provenance
