import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/service_locator.dart';
import 'package:stashify/services/stash_service.dart';
import 'package:stashify/screens/feed_screen.dart';
import 'package:stashify/screens/reader_screen.dart';
import 'package:stashify/widgets/empty_state.dart';
import 'package:stashify/widgets/stash_row.dart';
import 'package:stashify/widgets/stash_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final StashService _service = getIt<StashService>();

  void _remove(StashItem item) {
    final index = _service.items.value.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    _service.remove(item);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from stash.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _service.restore(item, index),
        ),
      ),
    );
  }

  void _openItem(StashItem item) {
    if (item.isFeed) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedScreen(feed: item, service: _service),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReaderScreen(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stashify'),
        actions: [
          IconButton(
            tooltip: 'Offline library',
            onPressed: () {},
            icon: const Icon(Icons.wifi_off_outlined),
          ),
        ],
      ),
      body: SafeArea(
        // The whole body scrolls as one: at a large text scale the intro
        // copy and the card grow together instead of pushing a fixed
        // header past the viewport.
        child: SignalBuilder(
          builder: (context) {
            final items = _service.items.value;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Save for offline reading',
                      style: text.headlineSmall,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Paste a link while online. It stays on this device.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: StashShell(service: _service),
                  ),
                ),
                SliverToBoxAdapter(child: _savedHeader(items.length)),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Nothing stashed yet',
                      body:
                          'Paste your first link above. It will appear '
                          'here and stay readable offline.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) => _remove(item),
                          child: StashRow(
                            item: item,
                            onOpen: () => _openItem(item),
                            onDelete: () => _remove(item),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _savedHeader(int count) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text('Saved', style: text.titleMedium),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.offline_pin_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'On this device',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
