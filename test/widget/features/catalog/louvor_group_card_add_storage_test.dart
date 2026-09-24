// test/widget/features/catalog/louvor_group_card_add_storage_test.dart
//
// A8: o «+» do card não pré-julga o Isar no toque. Enquanto o banco ainda
// está **abrindo** (`IsarStatus.opening`, web fria), quem decide é o editor da
// lista ativa: ele espera/grava e só devolve `storageUnavailable` quando o
// storage de fato não veio. A snackbar segue o resultado, não o status.
import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editor com resultado fixo — registra o que o card mandou adicionar.
class _StubActiveEditor extends ActivePlaylistEditor {
  _StubActiveEditor(this.outcome);

  final AddToActiveOutcome outcome;
  final List<({String id, MaterialKind? kind})> added = [];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add((id: materialId, kind: kind));
    return outcome;
  }
}

LouvorGroup _singlePdfGroup() {
  return LouvorGroup.fromLouvores([
    Louvor.fromManifest(
      nome: 'Aleluia',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Básico',
      pdf: 'pdf1.pdf',
      pdfId: 'pdf1',
      groupId: 'g1',
    ),
  ]).first;
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_StubActiveEditor> pumpAndTapAdd(
    WidgetTester tester, {
    required AddToActiveOutcome outcome,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final editor = _StubActiveEditor(outcome);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Web fria: o app já está na tela e o Isar ainda não resolveu.
          isarStatusProvider.overrideWithValue(IsarStatus.opening),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(body: LouvorGroupCard(group: _singlePdfGroup())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CarouselLouvorAddButton));
    await tester.pumpAndSettle();
    return editor;
  }

  testWidgets('com o Isar abrindo, o + entra pelo editor e não pré-julga', (
    tester,
  ) async {
    final editor = await pumpAndTapAdd(
      tester,
      outcome: AddToActiveOutcome.added,
    );

    expect(editor.added, [(id: 'pdf1', kind: MaterialKind.pdf)]);
    expect(find.text(pt.carouselAdded), findsOneWidget);
    expect(find.text(pt.playlistStorageUnavailable), findsNothing);
  });

  testWidgets('storageUnavailable do editor vira a snackbar de storage', (
    tester,
  ) async {
    await pumpAndTapAdd(tester, outcome: AddToActiveOutcome.storageUnavailable);

    expect(find.text(pt.playlistStorageUnavailable), findsOneWidget);
    expect(find.text(pt.carouselAdded), findsNothing);
  });

  testWidgets('alreadyPresent do editor vira «Já está na seleção»', (
    tester,
  ) async {
    await pumpAndTapAdd(tester, outcome: AddToActiveOutcome.alreadyPresent);

    expect(find.text(pt.carouselAlreadyAdded), findsOneWidget);
  });
}
