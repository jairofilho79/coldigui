import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/serialize_gesture_document.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/fixtures/gestures/$name').readAsStringSync();

void main() {
  group('serializeGestureDocument', () {
    test('roundtrip de 182_quero_viver.json preserva todos os dados', () {
      final originalJson = _fixture('182_quero_viver.json');
      final doc = parseGestureDocument(originalJson);

      final serialized = serializeGestureDocument(doc);
      final reparsed = parseGestureDocument(serialized);

      expect(reparsed.schemaMajor, doc.schemaMajor);
      expect(reparsed.title, doc.title);
      expect(reparsed.dictionaryVersion, doc.dictionaryVersion);
      expect(reparsed.items.length, doc.items.length);

      final coro = reparsed.items.first as ChorusBlock;
      final originalCoro = doc.items.first as ChorusBlock;
      expect(coro.children.length, originalCoro.children.length);

      final firstCard = coro.children.first as GestureCard;
      final origCard = originalCoro.children.first as GestureCard;
      expect(firstCard.gestureId, origCard.gestureId);
      expect(firstCard.lyrics.first.trigger, origCard.lyrics.first.trigger);
      expect(firstCard.lyrics.first.text, origCard.lyrics.first.text);
    });

    test('serializa todos os tipos de blocos e instruções', () {
      const doc = GestureDocument(
        schemaMajor: 1,
        title: 'Teste Completo',
        dictionaryVersion: 2,
        items: [
          GestureCard(
            gestureId: '1234567890ab',
            lyrics: [LyricLine(trigger: 'Abre', text: 'o coração')],
          ),
          RepeatBlock(
            count: 3,
            children: [TextLine('Repetir 3x')],
          ),
          ChorusBlock(
            children: [TextLine('Coro aqui')],
          ),
          LinkBlock(
            children: [
              GestureCard(
                gestureId: 'abcdef123456',
                lyrics: [LyricLine(trigger: '', text: 'Ligado')],
              ),
            ],
          ),
          FinalBlock(
            children: [TextLine('Final')],
          ),
          InstructionCard(InstructionKind.instruments),
          InstructionCard(InstructionKind.repeatPraise),
          InstructionCard(InstructionKind.backToChorus),
          InstructionCard(InstructionKind.backToChorusAndFinish),
          TextLine('Linha avulsa'),
        ],
      );

      final json = serializeGestureDocument(doc);
      final reparsed = parseGestureDocument(json);

      expect(reparsed.title, 'Teste Completo');
      expect(reparsed.dictionaryVersion, 2);
      expect(reparsed.items.length, 10);
      expect(reparsed.items[0], isA<GestureCard>());
      expect(reparsed.items[1], isA<RepeatBlock>());
      expect((reparsed.items[1] as RepeatBlock).count, 3);
      expect(reparsed.items[2], isA<ChorusBlock>());
      expect(reparsed.items[3], isA<LinkBlock>());
      expect(reparsed.items[4], isA<FinalBlock>());
      expect((reparsed.items[5] as InstructionCard).kind, InstructionKind.instruments);
      expect((reparsed.items[6] as InstructionCard).kind, InstructionKind.repeatPraise);
      expect((reparsed.items[7] as InstructionCard).kind, InstructionKind.backToChorus);
      expect((reparsed.items[8] as InstructionCard).kind, InstructionKind.backToChorusAndFinish);
      expect((reparsed.items[9] as TextLine).text, 'Linha avulsa');
    });
  });
}
