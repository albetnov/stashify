import 'package:flutter/material.dart';

import 'package:stashify/utils/link_utils.dart';

class SupportChip extends StatelessWidget {
  const SupportChip({super.key, required this.support, required this.onTap});

  final UrlSupport support;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = support != UrlSupport.none;
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        active ? Icons.check_circle : Icons.info_outline,
        size: 18,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
      label: Text(
        switch (support) {
          UrlSupport.feed => 'Feed supported',
          UrlSupport.article => 'Article supported',
          UrlSupport.none => 'Supports RSS + articles',
        },
      ),
    );
  }
}
