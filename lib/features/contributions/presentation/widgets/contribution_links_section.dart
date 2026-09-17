import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// «Links (YouTube / Drive)» (spec §6.2 item 9): campo + botão de adicionar
/// e a lista dos já aceitos. Mantém o próprio `TextEditingController` — o
/// texto digitado não faz parte do rascunho até `onAdd` aceitar o link.
class LinksSection extends StatefulWidget {
  const LinksSection({
    required this.links,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<String> links;

  /// `true` se o link foi aceito (e já entrou no rascunho).
  final bool Function(String) onAdd;
  final ValueChanged<int> onRemove;

  @override
  State<LinksSection> createState() => _LinksSectionState();
}

class _LinksSectionState extends State<LinksSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(AppLocalizations l10n) {
    final ok = widget.onAdd(_controller.text);
    if (ok) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.contributeLinkNotAllowed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contributeLinks,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.contributeAddLink,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
              onPressed: () => _add(l10n),
            ),
          ],
        ),
        if (widget.links.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.links.length; i++)
                Chip(
                  label: Text(widget.links[i]),
                  onDeleted: () => widget.onRemove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
