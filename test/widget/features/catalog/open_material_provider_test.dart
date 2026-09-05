// test/widget/features/catalog/open_material_provider_test.dart
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _louvor = Louvor.fromManifest(
  nome: 'Grande Deus',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'Coletânea',
  pdf: 'a.pdf',
  pdfId: 'pdf1',
  groupId: 'praise-1',
  source: LouvorDataSource.coldigom,
);

const _chord = ChordMaterial(
  chordId: 'chord1',
  r2Key: 'assets/praises/praise-1/a.chord',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'Cifra',
  classificacao: 'Coletânea',
);

const _track = AudioTrack(
  audioId: 'audio1',
  r2Key: 'assets/praises/praise-1/a.mp3',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'Áudio',
  classificacao: 'Coletânea',
);

const _youtube = YoutubeMaterial(
  id: 'yt1',
  url: 'https://youtu.be/1Pks43ceAac',
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'YouTube',
  classificacao: 'Coletânea',
);

/// Registra qual caminho o `switch` do opener tomou.
class _OpenerSpy {
  final calls = <String>[];
  bool youtubeResult = true;
  Object? pdfError;
  List<AudioTrack>? audioQueue;

  OpenMaterial build() {
    return OpenMaterial(
      openPdf: ({required ref, required context, required louvor}) async {
        calls.add('pdf:${louvor.pdfId}');
        final error = pdfError;
        if (error != null) throw error;
      },
      openChord: ({required ref, required context, required chord}) async {
        calls.add('chord:${chord.chordId}');
      },
      openAudio:
          ({
            required ref,
            required context,
            required track,
            List<AudioTrack>? queue,
          }) async {
            calls.add('audio:${track.audioId}');
            audioQueue = queue;
          },
      openYoutube: (material) async {
        calls.add('youtube:${material.id}');
        return youtubeResult;
      },
    );
  }
}

/// Monta um app mínimo e devolve `open(context, ref, material)` pronto.
Future<Future<void> Function(CatalogMaterial, {List<AudioTrack>? audioQueue})>
_mount(WidgetTester tester, OpenMaterial opener) async {
  late Future<void> Function(CatalogMaterial, {List<AudioTrack>? audioQueue})
  open;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [openMaterialProvider.overrideWithValue(opener)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) {
            open = (material, {audioQueue}) => ref
                .read(openMaterialProvider)
                .open(context, ref, material, audioQueue: audioQueue);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );

  return open;
}

void main() {
  group('OpenMaterial.open', () {
    testWidgets('PdfMaterial vai para o leitor de PDF', (tester) async {
      final spy = _OpenerSpy();
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));

      expect(spy.calls, ['pdf:pdf1']);
    });

    testWidgets('ChordMaterialRef vai para a cifra', (tester) async {
      final spy = _OpenerSpy();
      final open = await _mount(tester, spy.build());

      await open(const ChordMaterialRef(_chord));

      expect(spy.calls, ['chord:chord1']);
    });

    testWidgets('AudioMaterial vai para o player', (tester) async {
      final spy = _OpenerSpy();
      final open = await _mount(tester, spy.build());

      await open(const AudioMaterial(_track));

      expect(spy.calls, ['audio:audio1']);
      // Sem fila explícita o opener não inventa uma — quem tem o grupo passa.
      expect(spy.audioQueue, isNull);
    });

    testWidgets('AudioMaterial repassa a fila de quem tem o grupo', (
      tester,
    ) async {
      const other = AudioTrack(
        audioId: 'audio2',
        r2Key: 'assets/praises/praise-1/b.mp3',
        nome: 'Grande Deus',
        numero: '001',
        groupId: 'praise-1',
        categoria: 'Playback',
        classificacao: 'Coletânea',
      );
      final spy = _OpenerSpy();
      final open = await _mount(tester, spy.build());

      await open(
        const AudioMaterial(_track),
        audioQueue: const [_track, other],
      );

      expect(spy.calls, ['audio:audio1']);
      expect(spy.audioQueue, const [_track, other]);
    });

    testWidgets('YoutubeMaterialRef abre o link externo', (tester) async {
      final spy = _OpenerSpy();
      final open = await _mount(tester, spy.build());

      await open(const YoutubeMaterialRef(_youtube));

      expect(spy.calls, ['youtube:yt1']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('YouTube que não abre mostra aviso', (tester) async {
      final spy = _OpenerSpy()..youtubeResult = false;
      final open = await _mount(tester, spy.build());

      await open(const YoutubeMaterialRef(_youtube));
      await tester.pump();

      expect(find.text('Não foi possível abrir o YouTube'), findsOneWidget);
    });

    testWidgets('falha de abertura vira snackbar da escada única', (
      tester,
    ) async {
      final spy = _OpenerSpy()
        ..pdfError = const PdfOfflineUnavailableException(
          pdfId: 'pdf1',
          message: 'sem rede aqui',
        );
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));
      await tester.pump();

      expect(find.text('sem rede aqui'), findsOneWidget);
      // O PDF offline mantém a ação "Baixar" que o card já mostrava.
      expect(find.widgetWithText(SnackBarAction, 'Baixar'), findsOneWidget);
    });

    testWidgets('erro de PDF sem mensagem própria não ganha ação Baixar', (
      tester,
    ) async {
      final spy = _OpenerSpy()..pdfError = const PdfFetchFailedException('x');
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));
      await tester.pump();

      expect(find.text('x'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
    });

    testWidgets('erro sem mensagem própria cai no genérico', (tester) async {
      final spy = _OpenerSpy()..pdfError = StateError('boom');
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));
      await tester.pump();

      expect(
        find.text('Não foi possível concluir a ação. Tente de novo.'),
        findsOneWidget,
      );
    });

    // A2: erro sem mensagem própria mas classificável (rede, storage) não pode
    // cair no genérico — `userMessageFor` já sabe traduzir esses.
    testWidgets('falta de conexão vira o aviso de rede, não o genérico', (
      tester,
    ) async {
      final spy = _OpenerSpy()
        ..pdfError = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));
      await tester.pump();

      expect(
        find.text(
          'Sem conexão com a internet. Verifique sua rede e tente de novo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('storage indisponível vira o aviso de armazenamento', (
      tester,
    ) async {
      final spy = _OpenerSpy()
        ..pdfError = const StorageUnavailableException('offline.put');
      final open = await _mount(tester, spy.build());

      await open(PdfMaterial(_louvor));
      await tester.pump();

      expect(
        find.text(
          'Armazenamento local indisponível. Recarregue a página ou libere espaço.',
        ),
        findsOneWidget,
      );
    });
  });

  group('classifyMaterialOpenFailure', () {
    test('InvalidPdfPathException → genérico com stack', () {
      final failure = classifyMaterialOpenFailure(
        const InvalidPdfPathException('x'),
      );
      expect(failure.message, isNull);
      expect(failure.stage, 'caminho PDF inválido');
      expect(failure.logWithStack, isTrue);
    });

    test('PdfOfflineUnavailableException → mensagem própria sem stack', () {
      final failure = classifyMaterialOpenFailure(
        const PdfOfflineUnavailableException(pdfId: 'pdf1', message: 'offline'),
      );
      expect(failure.message, 'offline');
      expect(failure.stage, 'PDF offline indisponível');
      expect(failure.logWithStack, isFalse);
    });

    test('PdfExternallyDeletedException → stage sem mensagem própria', () {
      // Sem `message`: o texto sai do l10n (`pdfExternallyDeleted`, D.6) por
      // `userMessageFor`; aqui sobra o rótulo de log.
      final failure = classifyMaterialOpenFailure(
        const PdfExternallyDeletedException(pdfId: 'pdf1'),
      );
      expect(failure.message, isNull);
      expect(failure.stage, 'PDF removido externamente');
      expect(failure.logWithStack, isFalse);
    });

    test('PdfLocalCorruptedException → stage sem mensagem própria', () {
      final failure = classifyMaterialOpenFailure(
        const PdfLocalCorruptedException(pdfId: 'pdf1'),
      );
      expect(failure.message, isNull);
      expect(failure.stage, 'PDF local corrompido');
      expect(failure.logWithStack, isFalse);
    });

    test('PdfFetchFailedException → mensagem própria com stack', () {
      final failure = classifyMaterialOpenFailure(
        const PdfFetchFailedException('download'),
      );
      expect(failure.message, 'download');
      expect(failure.stage, 'falha ao baixar PDF');
      expect(failure.logWithStack, isTrue);
    });

    test('erro desconhecido usa o genericStage de quem chama', () {
      final failure = classifyMaterialOpenFailure(
        StateError('boom'),
        genericStage: '_openPdfInReader',
      );
      expect(failure.message, isNull);
      expect(failure.stage, '_openPdfInReader');
      expect(failure.logWithStack, isTrue);
    });
  });
}
