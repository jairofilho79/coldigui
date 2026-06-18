import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// UC-01 — Campo de busca da Home.
///
/// Não confundir com [SearchBar] do Material — widget específico PLPCG.
/// [onQueryChanged] propaga texto imediato; debounce 300ms fica no provider.
///
/// Widget [StatefulWidget] puro (sem Riverpod) para não reconstruir com
/// resultados da busca — input sempre fluido no main thread.
///
/// Layout compacto: `Row` com ícone lupa + [TextField] + botão limpar opcional
/// (sem `prefixIcon`/`suffixIcon` do Material — controles explícitos no `Row`).
/// Altura intrínseca via [GoldenTaggedContainer.compactContentPaddingFor].
///
/// **Botão limpar:** exibido quando o texto não está vazio (`ValueListenableBuilder`
/// no [TextEditingController]). Ao tocar: zera o controller, chama [onQueryChanged]
/// e [FocusNode.requestFocus] para manter o teclado aberto. Tooltip via
/// [AppLocalizations.searchClear].
class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    required this.hintText,
    required this.onQueryChanged,
    this.initialValue = '',
  });

  /// Texto do placeholder — tipicamente [AppLocalizations.searchHint].
  final String hintText;

  /// Callback imediato a cada alteração do texto (sem debounce).
  final ValueChanged<String> onQueryChanged;

  /// Valor inicial na criação do widget (ex.: query `pesquisa=` da URL).
  /// Não é re-sincronizado em rebuilds — hidratação externa recria via [Key].
  final String initialValue;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _glowActive = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _glowActive = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    final active = _focusNode.hasFocus;
    if (active == _glowActive) return;
    setState(() => _glowActive = active);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    widget.onQueryChanged('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GoldenTaggedContainer(
      label: l10n.searchLabel,
      glowEnabled: true,
      glowActive: _glowActive,
      contentPadding: GoldenTaggedContainer.compactContentPaddingFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: AppColors.title, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: AppTypography.body.copyWith(height: 1.1),
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle:
                    AppTypography.hint(italic: true).copyWith(height: 1.1),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onQueryChanged,
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
    );
  }
}
