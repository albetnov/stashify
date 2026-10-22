import 'package:fetch_forge/flutter.dart';
import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/stash_service.dart';
import 'package:stashify/widgets/stash_input.dart';

/// The card that stashes a link: the write, and the form that starts it.
///
/// It owns the [Mutation] and the outcome the user sees. The write itself
/// belongs to the [StashService]; the form belongs to [StashInput].
class StashShell extends StatelessWidget {
  const StashShell({super.key, required this.service});

  final StashService service;

  @override
  Widget build(BuildContext context) {
    return MutationBuilder<StashItem, String>(
      mutator: service.stash,
      builder: (context, view) => StashInput(
        isPending: view.isPending,
        onSubmit: (url) => _stash(context, view, url),
      ),
    );
  }

  Future<bool> _stash(
    BuildContext context,
    MutationView<StashItem, String> view,
    String url,
  ) async {
    try {
      await view.mutateAsync(url);
      if (!context.mounted) return true;
      _toast(context, 'Saved for offline reading.');
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      _toast(
        context,
        error is StashException
            ? error.message
            : 'Couldn’t stash that link. Try again.',
      );
      return false;
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
