import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/core/utils/score_reader_url_builder.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_target.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_material.dart';
import 'package:coldigui/features/score_reader/presentation/utils/open_score_in_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const _r2Key = 'assets/praises/praise-1/mat-9.mscz';

ScoreMaterial _score({String r2Key = _r2Key}) => ScoreMaterial(
  scoreId: encodePdfId(r2Key),
  r2Key: r2Key,
  nome: 'Grande Deus',
  numero: '001',
  groupId: 'praise-1',
  categoria: 'Partitura',
  classificacao: 'Coletânea',
);

void main() {
  group('classificação do tipo', () {
    test('extensões de partitura editável viram MaterialKind.score', () {
      for (final ext in ['mscz', 'mxl', 'musicxml']) {
        final id = encodePdfId('assets/praises/p/m.$ext');
        expect(materialIdKindOf(id), MaterialKind.score, reason: ext);
        expect(materialKindOfRawType(ext), MaterialKind.score, reason: ext);
      }
    });

    test('PDF continua PDF', () {
      expect(
        materialIdKindOf(encodePdfId('assets/praises/p/m.pdf')),
        MaterialKind.pdf,
      );
    });

    test('são baixáveis offline', () {
      for (final type in ['mscz', 'mxl', 'musicxml', 'MSCZ']) {
        expect(isColdigomDownloadableType(type), isTrue, reason: type);
      }
    });

    test('wire genérico (pdf/unknown) cede à extensão de partitura', () {
      final id = encodePdfId(_r2Key);
      expect(resolveWireKind(MaterialKind.pdf, id), MaterialKind.score);
      expect(resolveWireKind(MaterialKind.unknown, id), MaterialKind.score);
    });
  });

  group('rota /partitura', () {
    test('buildScoreReaderLocation codifica id e título', () {
      final location = buildScoreReaderLocation(
        scoreId: 'abc',
        titulo: 'Grande Deus',
        subtitulo: '001',
      );
      final uri = Uri.parse(location);
      expect(uri.path, '/partitura');
      expect(uri.queryParameters['pdfId'], 'abc');
      expect(uri.queryParameters['titulo'], 'Grande Deus');
      expect(uri.queryParameters['subtitulo'], '001');
    });

    test('scoreRouteFor ignora o que não é partitura', () {
      final route = scoreRouteFor(
        encodePdfId('assets/praises/p/m.pdf'),
        const {},
      );
      expect(route.isScore, isFalse);
      expect(route.location, isNull);
    });

    test('scoreRouteFor navega com cache frio (só perde o título)', () {
      final id = encodePdfId(_r2Key);
      final route = scoreRouteFor(id, const {});
      expect(route.isScore, isTrue);
      final uri = Uri.parse(route.location!);
      expect(uri.queryParameters['pdfId'], id);
      expect(uri.queryParameters.containsKey('titulo'), isFalse);
    });

    test('scoreRouteFor usa o título do cache quente', () {
      final score = _score();
      final route = scoreRouteFor(score.scoreId, {score.scoreId: score});
      expect(
        Uri.parse(route.location!).queryParameters['titulo'],
        'Grande Deus',
      );
    });
  });

  group('catálogo', () {
    test('adapter extrai só as partituras editáveis do praise', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Grande Deus',
        number: '001',
        rhythm: 'Coletânea',
        materials: [
          MaterialDto(
            id: 'mat-1',
            type: 'pdf',
            r2Key: 'assets/praises/praise-1/mat-1.pdf',
          ),
          MaterialDto(
            id: 'mat-9',
            type: 'mscz',
            r2Key: _r2Key,
            materialKindId: 'k-voz',
            materialKindName: 'Grade',
          ),
          MaterialDto(id: 'mat-10', type: 'mxl'),
        ],
      );

      final scores = ColdigomLouvorAdapter.toScoreMaterials(praise);

      expect(scores, hasLength(1));
      final score = scores.single;
      expect(score.scoreId, encodePdfId(_r2Key));
      expect(score.r2Key, _r2Key);
      expect(score.groupId, 'praise-1');
      expect(score.categoria, 'Grade');
      expect(score.materialKindId, 'k-voz');
    });

    test('LouvorGroup agrupa partituras pelo groupId e as expõe como extra', () {
      final groups = LouvorGroup.fromLouvores(
        const [],
        scoreMaterials: [_score()],
      );

      expect(groups, hasLength(1));
      final group = groups.single;
      expect(group.groupId, 'praise-1');
      expect(group.nome, 'Grande Deus');
      expect(group.scoreMaterials.single.r2Key, _r2Key);
      expect(group.extras.whereType<ScoreMaterialRef>(), hasLength(1));
      expect(
        group.extras.whereType<ScoreMaterialRef>().single.kind,
        MaterialKind.score,
      );
    });
  });
}
