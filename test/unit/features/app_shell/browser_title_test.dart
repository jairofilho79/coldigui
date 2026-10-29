import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/app_shell/presentation/utils/browser_title.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  test('leitor/cifra com número — «numero — nome · PLPCG»', () {
    final title = browserTitle(
      l10n: l10n,
      readerParams: const {
        UrlSyncParams.titulo: 'Grandioso És Tu',
        UrlSyncParams.subtitulo: '123',
      },
      trackTitle: null,
      tabLabel: 'Biblioteca',
    );

    expect(title, '123 — Grandioso És Tu · PLPCG');
  });

  test('leitor/cifra sem número — «nome · PLPCG»', () {
    final title = browserTitle(
      l10n: l10n,
      readerParams: const {UrlSyncParams.titulo: 'Grandioso És Tu'},
      trackTitle: null,
      tabLabel: 'Biblioteca',
    );

    expect(title, 'Grandioso És Tu · PLPCG');
  });

  test('/audio — faixa atual sem sufixo de marca', () {
    final title = browserTitle(
      l10n: l10n,
      readerParams: const {},
      trackTitle: '047 — Shekinah',
      tabLabel: 'Áudio',
    );

    expect(title, '047 — Shekinah');
  });

  test('fora do leitor/cifra/áudio — «label · PLPCG»', () {
    final title = browserTitle(
      l10n: l10n,
      readerParams: const {},
      trackTitle: null,
      tabLabel: 'Biblioteca',
    );

    expect(title, 'Biblioteca · PLPCG');
  });

  test('leitor/cifra vence mesmo com trackTitle presente (prioridade)', () {
    final title = browserTitle(
      l10n: l10n,
      readerParams: const {UrlSyncParams.titulo: 'Grandioso És Tu'},
      trackTitle: '047 — Shekinah',
      tabLabel: 'Biblioteca',
    );

    expect(title, 'Grandioso És Tu · PLPCG');
  });
}
