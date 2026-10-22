import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'package:stashify/utils/link_utils.dart';
import 'package:stashify/widgets/stash_sheets.dart';
import 'package:stashify/widgets/support_chip.dart';

class StashInput extends StatefulWidget {
  const StashInput({
    super.key,
    required this.onSubmit,
    required this.isPending,
  });

  /// Starts the write for the URL in the field and reports whether it
  /// worked.
  final Future<bool> Function(String url) onSubmit;

  final ReadonlySignal<bool> isPending;

  @override
  State<StashInput> createState() => _StashInputState();
}

class _StashInputState extends State<StashInput> {
  final _urlController = TextEditingController();

  StashSupport _support = StashSupport.none;
  String? _fieldError;

  /// Whether the link in the field can be stashed.
  ///
  /// An article on an unsupported site cannot, so the button greys out and
  /// the badge says why. A link that is not a link yet leaves the button
  /// live: tapping it says what is wrong with it.
  bool get _stashable =>
      _support != StashSupport.unsupportedArticle &&
      _urlController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController
      ..removeListener(_onUrlChanged)
      ..dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    setState(() {
      _support = supportFor(_urlController.text);
      if (_fieldError != null && _urlController.text.trim().isNotEmpty) {
        _fieldError = null;
      }
    });
  }

  Future<void> _submit() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;

    if (supportFor(raw) == StashSupport.none) {
      setState(() {
        _fieldError = 'Enter a valid http(s) link to an article or feed.';
      });
      return;
    }

    setState(() => _fieldError = null);

    final saved = await widget.onSubmit(raw);
    if (!mounted) return;

    if (saved) {
      _urlController.clear();
    } else {
      // The link stays in the field: the user can fix it and stash it again.
      _urlController.text = raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Paste article or feed URL',
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        onPressed: _urlController.clear,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                errorText: _fieldError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SignalBuilder(
              builder: (context) {
                final pending = widget.isPending.value;
                final canStash = _stashable && !pending;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SupportChip(
                      support: _support,
                      onTap: () => showSupportedSheet(context),
                    ),
                    FilledButton.icon(
                      onPressed: canStash ? _submit : null,
                      icon: pending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(pending ? 'Stashing…' : 'Stash'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
