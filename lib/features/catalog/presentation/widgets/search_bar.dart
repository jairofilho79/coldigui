import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_search_provider.dart';

/// UC-01 — Campo de busca da Home.
///
/// Não confundir com [SearchBar] do Material — widget específico PLPCG.
/// Atualiza [homeSearchRawQueryProvider]; debounce 300ms no provider.
///
/// Layout compacto: `Row` com ícone lupa + [TextField] + botão limpar opcional
/// (sem `prefixIcon`/`suffixIcon` do Material — controles explícitos no `Row`).
/// [GoldenTaggedContainer.compactContentPadding] e
/// [GoldenTaggedContainer.compactRowHeight].
///
/// **Botão limpar:** exibido quando o texto não está vazio (`ValueListenableBuilder`
/// no [TextEditingController]). Ao tocar: zera o controller, atualiza
/// [homeSearchRawQueryProvider] e chama [FocusNode.requestFocus] para manter o
/// teclado aberto. Tooltip via [AppLocalizations.searchClear].
class SearchBar extends ConsumerStatefulWidget {
  const SearchBar({
    super.key,
    required this.hintText,
    this.initialValue = '',
  });

  /// Texto do placeholder — tipicamente [AppLocalizations.searchHint].
  final String hintText;

  /// Valor inicial (ex.: query `pesquisa=` da URL).
  final String initialValue;

  @override
  ConsumerState<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(homeSearchRawQueryProvider.notifier).state = '';
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GoldenTaggedContainer(
      label: l10n.searchLabel,
      glowEnabled: true,
      contentPadding: GoldenTaggedContainer.compactContentPadding,
      child: SizedBox(
        height: GoldenTaggedContainer.compactRowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search, color: AppColors.title, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTypography.body.copyWith(height: 1.2),
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.hint(italic: true),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  ref.read(homeSearchRawQueryProvider.notifier).state = value;
                },
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: l10n.searchClear,
                    onPressed: _clearSearch,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.title,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
