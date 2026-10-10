import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/device/device_snapshot_provider.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/presentation/pages/contribute_screen.dart';
import 'package:coldigui/features/contributions/presentation/widgets/extracted_editor/extracted_chord_editor.dart';
import 'package:coldigui/features/contributions/presentation/widgets/extracted_editor/extracted_gesture_editor.dart';
import 'package:coldigui/features/contributions/presentation/widgets/extracted_editor/extracted_lyrics_editor.dart';
import 'package:coldigui/features/contributions/presentation/widgets/extracted_editor/gesture_picker_modal.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_device_snapshot_port.dart';
import '../../../support/pump_app.dart';

const _mockUser = AuthUser(
  googleSub: 'u1',
  email: 'user@teste.com',
  name: 'User Teste',
  sessionToken: 'sess_valid',
);

final _mockDictionary = GestureDictionary(
  version: 1,
  generatedAt: DateTime(2026),
  byId: {
    'c687580e7682': GestureEntry(
      id: 'c687580e7682',
      name: 'Coração',
      description: 'Mão no peito',
      exampleTriggers: ['coração', 'amor'],
      image: 'assets/cia/gestures/c687580e7682.png',
      gif: null,
      status: GestureStatus.active,
      replacedBy: null,
      updatedAt: null,
    ),
    '5d3a00000000': GestureEntry(
      id: '5d3a00000000',
      name: 'Oração',
      description: 'Mãos postas',
      exampleTriggers: ['orar', 'clamar'],
      image: 'assets/cia/gestures/5d3a00000000.png',
      gif: null,
      status: GestureStatus.active,
      replacedBy: null,
      updatedAt: null,
    ),
  },
);

void main() {
  group('ExtractedLyricsEditor', () {
    testWidgets('exibe texto inicial e permite adicionar e remover linhas', (tester) async {
      String currentText = 'Linha 1\nLinha 2';

      await pumpApp(
        tester,
        ExtractedLyricsEditor(
          initialLyrics: currentText,
          onChanged: (val) => currentText = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linha 1\nLinha 2'), findsOneWidget);

      // Toca em adicionar linha
      await tester.tap(find.text('Adicionar linha'));
      await tester.pumpAndSettle();

      expect(currentText, contains('Linha 1\nLinha 2\n\n'));

      // Toca em remover linha
      await tester.tap(find.text('Remover linha'));
      await tester.pumpAndSettle();

      expect(currentText, contains('Linha 1\nLinha 2'));

      // Alterna entre abas
      await tester.tap(find.text('Pré-visualização'));
      await tester.pumpAndSettle();

      expect(find.text('2 versos'), findsOneWidget);
    });
  });

  group('ExtractedChordEditor', () {
    testWidgets('permite editar ChordPro e inserir atalhos', (tester) async {
      String currentText = '[G]Louvai ao [D]Senhor';

      await pumpApp(
        tester,
        ExtractedChordEditor(
          initialChordPro: currentText,
          onChanged: (val) => currentText = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('[G]Louvai ao [D]Senhor'), findsOneWidget);

      // Inserir tag de acorde
      await tester.tap(find.text('Inserir acorde [ ]'));
      await tester.pumpAndSettle();

      expect(currentText, contains('[C]'));

      // Alternar para pré-visualização
      await tester.tap(find.text('Pré-visualização'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  group('ExtractedGestureEditor', () {
    testWidgets('permite gerenciar cartões, adicionar e remover linhas', (tester) async {
      GestureDocument doc = const GestureDocument(
        schemaMajor: 1,
        title: 'Louvor Teste',
        dictionaryVersion: 1,
        items: [
          GestureCard(
            gestureId: 'c687580e7682',
            lyrics: [LyricLine(trigger: 'Abre', text: 'o coração')],
          ),
        ],
      );

      await pumpApp(
        tester,
        ExtractedGestureEditor(
          initialDocument: doc,
          onChanged: (newDoc) => doc = newDoc,
        ),
        overrides: [
          gestureDictionaryProvider.overrideWith((ref) => _mockDictionary),
          gestureFigureProvider.overrideWith((ref, key) => null),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coração'), findsOneWidget);
      expect(find.text('Abre'), findsOneWidget);
      expect(find.text('o coração'), findsOneWidget);

      // Adiciona linha de texto livre
      await tester.tap(find.text('Adicionar texto livre'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(doc.items.length, 2);
      expect(doc.items.last, isA<TextLine>());

      // Remove a linha de texto
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(doc.items.length, 1);
    });

    testWidgets('GesturePickerModal permite buscar e selecionar gesto', (tester) async {
      String? selectedId;

      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selectedId = await GesturePickerModal.show(context);
            },
            child: const Text('Abrir'),
          ),
        ),
        overrides: [
          gestureDictionaryProvider.overrideWith((ref) => _mockDictionary),
          gestureFigureProvider.overrideWith((ref, key) => null),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Escolher gesto'), findsOneWidget);
      expect(find.text('Coração'), findsOneWidget);
      expect(find.text('Oração'), findsOneWidget);

      // Seleciona Oração
      await tester.tap(find.text('Oração'));
      await tester.pumpAndSettle();

      expect(selectedId, '5d3a00000000');
    });
  });

  group('ContributeScreen com materiais extraídos', () {
    testWidgets('com target lyrics abre o ExtractedLyricsEditor e permite alternar', (tester) async {
      await pumpApp(
        tester,
        const ContributeScreen(
          target: ContributionTarget(
            source: ContributionSource.coldigom,
            praiseId: '182',
            materialId: 'lyrics:182',
          ),
        ),
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthNotifier(_mockUser)),
          deviceSnapshotPortProvider.overrideWithValue(FakeDeviceSnapshotPort()),
          gestureDictionaryProvider.overrideWith((ref) => _mockDictionary),
          gestureFigureProvider.overrideWith((ref, key) => null),
        ],
      );
      await tester.pumpAndSettle();

      // Editor de letra exibido
      expect(find.byType(ExtractedLyricsEditor), findsOneWidget);
      expect(find.text('Sugerir melhoria no material'), findsOneWidget);

      // Rola até o botão de alternar para formulário comum
      final switchBtnFinder = find.text('Alternar para formulário comum');
      await tester.ensureVisible(switchBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedLyricsEditor), findsNothing);
      expect(find.byKey(const Key('contribute-body')), findsOneWidget);

      // Pode voltar para o editor de letra pelo chip
      final lyricsChip = find.byKey(const Key('contribute-chip-lyrics'));
      await tester.ensureVisible(lyricsChip);
      await tester.pumpAndSettle();
      await tester.tap(lyricsChip);
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedLyricsEditor), findsOneWidget);
    });
  });
}
