import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/pdf_id_codec.dart';
import 'features/score_reader/data/providers/score_providers.dart';
import 'features/score_reader/demo/score_reader_demo_fixture.dart';
import 'features/score_reader/presentation/pages/score_reader_screen.dart';
import 'l10n/app_localizations.dart';

/// `flutter run -t lib/main_score_reader_demo.dart`
///
/// Abre a tela real sem bootstrap, conta ou consulta ao catálogo. Áudio usa o
/// motor real e o SoundFont mínimo embutido, inclusive offline. O banco completo
/// só é solicitado ao tocar/selecionar timbres, como no leitor normal.
/// Para um SF3 servido localmente, acrescente:
/// `--dart-define=SCORE_SOUNDFONT_KEY=http://127.0.0.1:8000/meu-banco.sf3`
/// (na web, o servidor do SF3 precisa permitir CORS).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [scoreReaderDemoDocumentOverride],
      child: const ScoreReaderDemoApp(),
    ),
  );
}

// Só esta chave é substituída; documentos do catálogo mantêm seu provider.
final scoreReaderDemoDocumentOverride = scoreDocumentProvider(
  scoreReaderDemoKey,
).overrideWith((ref) async => loadScoreReaderDemoDocument());

class ScoreReaderDemoApp extends StatelessWidget {
  const ScoreReaderDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Partitura · demo autoral',
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pt'),
    home: Scaffold(
      body: ScoreReaderScreen(
        queryParams: {'pdfId': encodePdfId(scoreReaderDemoKey)},
      ),
    ),
  );
}
