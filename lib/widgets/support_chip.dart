import 'package:flutter/material.dart';

import 'package:stashify/utils/link_utils.dart';

class SupportChip extends StatelessWidget {
  const SupportChip({
    super.key,
    required this.support,
    required this.onTap,
  });

  final StashSupport support;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (icon, label, tint) = switch (support) {
      StashSupport.feed => (
          Icons.check_circle,
          'Feed supported',
          scheme.primary,
        ),
      StashSupport.supportedArticle => (
          Icons.check_circle,
          'Article supported',
          scheme.primary,
        ),
      StashSupport.unsupportedArticle => (
          Icons.block,
          'Not supported',
          scheme.error,
        ),
      StashSupport.none => (
          Icons.info_outline,
          'RSS feeds always work',
          scheme.onSurfaceVariant,
        ),
    };

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: tint),
      label: Text(label),
    );
  }
}
