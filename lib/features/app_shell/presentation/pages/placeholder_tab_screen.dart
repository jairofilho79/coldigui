import 'package:flutter/material.dart';

/// Aba ainda sem conteúdo — título + “Em breve”.
///
/// Layout alinhado ao [AboutScreen] (`maxWidth: 896`).
class PlaceholderTabScreen extends StatelessWidget {
  const PlaceholderTabScreen({required this.title, super.key});

  final String title;

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('Em breve', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
