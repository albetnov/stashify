---
version: 1
slug: "lib-screens-reader-screen-dart"
primary_target: "lib/screens/reader_screen.dart"
related_targets: ["lib/widgets/article_view.dart"]
---

# Reader screen

## Scope

A full-screen route in Stashify (Android, Flutter). It renders a stashed
article's parsed `Article` blocks in reading order. Visitor mode: Read — the
visitor stashed a page while online and now reads it with no connection.

- Audience: the offline commuter with an article already in the stash.
- Job: read the stashed article end to end without a connection.
- Action: open a stashed article from the library and read down the column.
- Content: the real title, cover, and body blocks parsed from a supported
  site (albetnv.dev): headings, paragraphs with links and code spans,
  images, code blocks with language, ordered and bullet lists, quotes.
- Constraints: everything is in memory for now; images degrade to a muted
  box with alt text when offline; links stay recognisable and explain they
  need a connection.
- Unresolved: feed entry bodies are not stored yet, so feed entries keep
  their honest placeholder.

## Direction contract

THESIS: A stashed article is only useful if it reads like the page it came
from, minus the network. The screen exists to let the visitor read, so the
column is the screen and the chrome is one bar. It refuses the browser
chrome arrangement — no address bar, no tabs, no share row — because the
stash is a shelf of things already kept, not a window onto the web.

OWN-WORLD: The app's settled world: the green-seeded Material 3 scheme
(#0B6B4F), surfaceContainerHigh fills in the library, the M3 type scale
(headlineSmall titles, bodyLarge reading text, bodySmall muted meta),
12–16px radii, hairline dividers, and the offline-pin motif. The reader
inherits that scheme, that type scale, and the library's rhythm of a title
followed by a muted meta line; muted text stays tinted from the scheme,
never gray. Code sits on surfaceContainerHigh with a mono face and a small
primary language label. No new palette, no new face, no new shape language.

STORY: The visitor stashed an albetnv.dev page; tapping it opens the
article it holds. The title first, then when it was saved and how long it
takes, then the cover when the page had one, then the body in the order the
page meant: headings that open sections, paragraphs that carry links and
code spans, code blocks that keep their shape, lists that keep their
bullets and numbers, quotes that sit apart, images that hold their place
even offline. The visitor leaves knowing: this is the page I kept, it is
all here, and it reads with no connection.

FIRST VIEWPORT: The app bar carries only where the reader is — the domain
in the title slot with the offline pin trailing, the bar never growing for
the article. Below that, the column begins: the title (headlineSmall) with
the saved line tight under it ("2h ago · 6 min read · available offline",
bodySmall, muted), a hairline rule, then the cover in a 16px clip when the
page had one. The body follows at bodyLarge with 6px paragraph rhythm;
headings carry 24px above and 8px below; code, images and quotes breathe at
12px. The column never runs edge to edge: 20px gutters, capped at 640px so
a tablet holds one calm measure. The first section sits ~12px under the
cover.

FORM: An extension of the feed screen's document rhythm — the same
title-then-muted-meta opener and hairline rules, but the list of entries
gives way to one reading column. The structure is a single centered
CustomScrollView rather than cards: an article is a document, not a gallery.
seed:549cbb7cb26bd9a8

FINISH: unreviewed and undocumented is unfinished; this build ends with the
finish review, the verdict, DESIGN.md, and every shipping raster carrying
its provenance
