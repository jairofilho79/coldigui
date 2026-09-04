import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/presentation/providers/available_chords_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = 'g1';
const _okKey = 'assets/praises/p1/ok.chord';
const _falhaKey = 'assets/praises/p1/falha.chord';
const _semCifraKey = 'assets/praises/p1/vazio.chord';

ChordMaterial _material(String r2Key, String categoria) => ChordMaterial(
  chordId: r2Key,
  r2Key: r2Key,
  nome: 'Comigo',
  numero: '001',
  groupId: _group,
  categoria: categoria,
  classificacao: 'Adultos',
);

ProviderContainer _container(Map<String, ChordMaterial> chords) {
  final container = ProviderContainer(
    overrides: [
      chordSongProvider.overrideWith((ref, r2Key) async {
        if (r2Key == _falhaKey) {
          throw const ChordFetchFailedException(_falhaKey, 'rede fora');
        }
        if (r2Key == _semCifraKey) return null;
        return parseChordSongOrNull('{title: Comigo}\n\nA [Bb]noite vem,\n');
      }),
    ],
  );
  addTearDown(container.dispose);
  container.read(coldigomChordMaterialsCacheProvider.notifier).state = chords;
  return container;
}

void main() {
  test('cifra sem arquivo (404) continua fora da lista', () async {
    final container = _container({
      _okKey: _material(_okKey, 'Cifra I'),
      _semCifraKey: _material(_semCifraKey, 'Cifra II'),
    });

    final chords = await container.read(availableChordsProvider(_group).future);

    expect(chords.map((c) => c.r2Key), [_okKey]);
  });

  test('falha de rede numa cifra nao apaga as outras nem ela mesma', () async {
    final container = _container({
      _okKey: _material(_okKey, 'Cifra I'),
      _falhaKey: _material(_falhaKey, 'Cifra II'),
    });

    final chords = await container.read(availableChordsProvider(_group).future);

    expect(chords.map((c) => c.r2Key), [_okKey, _falhaKey]);
  });

  test('falha em todas ainda lista as cifras do catalogo', () async {
    final container = _container({_falhaKey: _material(_falhaKey, 'Cifra I')});

    final chords = await container.read(availableChordsProvider(_group).future);

    expect(chords.map((c) => c.r2Key), [_falhaKey]);
  });

  // A4: contrato real do provider — `_isPublished` engole a falha de rede, então
  // este provider **nunca** emite `AsyncError` por cifra que não respondeu. É
  // por isso que a linha "cifra indisponível · tentar de novo" do
  // `material_sheet` é código defensivo: em produção ela não aparece por falha
  // de rede numa cifra. Se algum dia este teste ficar vermelho, a linha do sheet
  // passou a ser alcançável de verdade.
  test(
    'falha de rede nunca vira AsyncError (contrato que o sheet defende)',
    () async {
      final container = _container({
        _okKey: _material(_okKey, 'Cifra I'),
        _falhaKey: _material(_falhaKey, 'Cifra II'),
      });

      await container.read(availableChordsProvider(_group).future);
      final state = container.read(availableChordsProvider(_group));

      expect(state.hasError, isFalse);
      expect(state.hasValue, isTrue);
    },
  );
}
