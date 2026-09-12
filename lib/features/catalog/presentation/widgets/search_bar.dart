import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/golden_tagged_container.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decide se a busca abre já com o cursor dentro (C1).
///
/// Web e desktop têm teclado físico: quem chega no pesquisador quer digitar, e
/// o campo é o único destino plausível. No celular o autofoco abriria o teclado
/// virtual por cima dos resultados sem ninguém pedir.
bool shouldAutofocusSearch({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return true;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

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
///
/// **Teclado (C1):** `Enter` dispara [onSubmitted] (a Home abre o primeiro
/// resultado), `Esc` limpa o campo, e o autofoco segue [shouldAutofocusSearch].
class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    required this.hintText,
    required this.onQueryChanged,
    this.initialValue = '',
    this.focusNode,
    this.onSubmitted,
    this.capabilities,
  });

  /// [FocusNode] externo — a Home usa para o atalho `Ctrl+K` / `/`.
  /// Quando `null`, o widget cria e descarta o seu.
  final FocusNode? focusNode;

  /// Capacidades da plataforma usadas em [shouldAutofocusSearch] (C1).
  ///
  /// `null` cai em [currentPlatformCapabilities] — mantém os testes que
  /// montam [SearchBar] sem `ProviderScope` funcionando (T2). Em produção o
  /// pai com `ref` (`home_screen.dart`) passa `platformCapabilitiesProvider`.
  final PlatformCapabilities? capabilities;

  /// Enter no campo. Recebe o texto atual.
  final ValueChanged<String>? onSubmitted;

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
  FocusNode? _ownedFocusNode;
  var _glowActive = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? (_ownedFocusNode = FocusNode());
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
    _ownedFocusNode?.dispose();
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

    // ponytail: tap em qualquer ponto da caixa foca o TextField
    return CallbackShortcuts(
      bindings: {
        // Esc limpa em vez de só tirar o foco: o usuário que aperta Esc numa
        // busca quer a lista inteira de volta.
        const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNode.requestFocus(),
        child: GoldenTaggedContainer(
          label: l10n.searchLabel,
          glowEnabled: true,
          glowActive: _glowActive,
          contentPadding: GoldenTaggedContainer.compactContentPaddingFor(
            context,
          ),
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
                    hintStyle: AppTypography.hint(
                      italic: true,
                    ).copyWith(height: 1.1),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  autofocus: shouldAutofocusSearch(
                    isWeb:
                        (widget.capabilities ?? currentPlatformCapabilities())
                            .isWeb,
                    platform: defaultTargetPlatform,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onQueryChanged,
                  onSubmitted: widget.onSubmitted,
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
      ),
    );
  }
}
