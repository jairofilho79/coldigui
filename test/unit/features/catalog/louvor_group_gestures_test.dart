import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _chord = ChordMaterial(chordId: 'c', r2Key: 'k.chord', nome: 'N', numero: '1', groupId: 'g', categoria: 'Cifra', classificacao: 'x');
const _gesture = GestureMaterial(gestureId: 'g1', r2Key: 'k.gestures', nome: 'N', numero: '1', groupId: 'g', categoria: 'Gestos', classificacao: 'x');

void main() {
  test('gestureMaterials entra em extras depois das cifras e antes do áudio', () {
    final group = LouvorGroup(
      groupId: 'g', numero: '1', nome: 'N', sections: const [],
      chordMaterials: const [_chord], gestureMaterials: const [_gesture],
    );
    expect(group.extras.map((m) => m.runtimeType), [ChordMaterialRef, GestureMaterialRef]);
    expect(group.gestureMaterials.single.gestureId, 'g1');
    expect(group.isColdigom, isTrue);
  });

  test('fromLouvores agrupa gestos pelo groupId', () {
    final groups = LouvorGroup.fromLouvores(const [], gestureMaterials: const [_gesture]);
    expect(groups.single.groupId, 'g');
    expect(groups.single.gestureMaterials, hasLength(1));
    expect(groups.single.nome, 'N');
  });
}
