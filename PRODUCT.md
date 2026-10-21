# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Primary: offline commuter — someone with intermittent or no connectivity (commute, flights, low-signal areas) who wants to stash web / RSS content beforehand and read it later without a connection.

Other audiences: none confirmed.

## Product Purpose

Stashify lets a user paste a URL and read the content offline later.

Flow: paste URL → 1. Fetching → 2. Parsing & Saving → 3. Offline Reading.

Success means a pasted URL reliably becomes a locally stored, readable article even when the device goes offline.

## Positioning

Simple offline stash: paste a URL and Stashify auto-fetches, parses, and stores it locally for full offline reading. Unlike Feedly / Inoreader / Pocket-style managers or account-backed sync readers, the core promise is a minimal save-and-read loop with local persistence as the mechanism.

## Operating Context

User pastes a URL when online; Stashify fetches and parses in the foreground; reading happens offline. Current repo is a default Flutter counter scaffold (`lib/main.dart`) with Android / iOS / desktop / web folders present, but v1 scope is Android-first.

## Capabilities and Constraints

Confirmed:

- Paste URL input as entry point.
- Fetch remote content when online.
- Parse and save content to device for offline access.
- Offline reading of saved items.
- Flutter codebase (v1.0.0+1), Material design enabled.

Undecided (do not assume): feed subscription vs. single-URL stash, feed/folder management, search, read/unread state, image / full-text caching policy, storage limits and eviction, background sync, OPML import, notifications.

Constraint: v1 targets Android; other Flutter targets in repo are out of scope until confirmed.

## Brand Commitments

Name: Stashify. No confirmed voice, logo, assets, or identity constraints.

## Evidence on Hand

No product copy, designs, testimonials, or datasets. Only evidence is the default Flutter template (`lib/main.dart`, `pubspec.yaml`). Future work must not fabricate users, benchmarks, or content sources.

## Product Principles

1. Offline-first: saved content must be fully readable with no connection.
2. Minimal loop: paste → fetch → read, with no account or setup friction.
3. Reliable persistence: what the user stashed stays available.
4. Honest state: surface fetching / parsing / saved so failures are visible.
