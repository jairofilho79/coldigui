import '../../../../core/utils/url_sync_params.dart';
import '../../../../l10n/app_localizations.dart';

/// Título da aba do navegador por rota (C14) — função pura consumida pelo
/// [Title] que envolve o corpo do `Scaffold` em `ShellScaffold`.
///
/// Prioridade: leitor/cifra ([readerParams] com [UrlSyncParams.titulo]) >
/// faixa tocando em `/audio` ([trackTitle], devolvida como está, sem sufixo de
/// marca) > rótulo da aba corrente ([tabLabel]).
///
/// [readerParams] fica vazio fora de `/leitor` e `/cifra`; [trackTitle] só é
/// passado (não nulo) em `/audio` — a decisão de qual delas vale é do
/// chamador (`ShellScaffold`), que sabe a rota atual.
String browserTitle({
  required AppLocalizations l10n,
  required Map<String, String> readerParams,
  required String? trackTitle,
  required String tabLabel,
}) {
  final nome = readerParams[UrlSyncParams.titulo];
  if (nome != null && nome.isNotEmpty) {
    final numero = readerParams[UrlSyncParams.subtitulo];
    if (numero != null && numero.isNotEmpty) {
      return l10n.browserTitleLouvor(numero, nome);
    }
    return l10n.browserTitleLouvorSemNumero(nome);
  }

  if (trackTitle != null && trackTitle.isNotEmpty) {
    return trackTitle;
  }

  return l10n.browserTitleTab(tabLabel);
}
