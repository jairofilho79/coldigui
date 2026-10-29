import 'dart:async';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Datasource controlável — nunca toca rede de verdade.
class _ControllableColdigomDatasource extends ColdigomRemoteDatasource {
  _ControllableColdigomDatasource(this._handler) : super(Dio());

  final Future<PraiseDetailDto> Function(String praiseId) _handler;
  final calls = <String>[];

  @override
  Future<PraiseDetailDto> fetchDetail(String praiseId) {
    calls.add(praiseId);
    return _handler(praiseId);
  }
}

/// Expõe [warmupColdigomPraiseIds] (que exige [Ref]) via um Notifier.
class _WarmupRunner extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> run(Iterable<String> praiseIds, {Duration? timeout}) {
    return timeout == null
        ? warmupColdigomPraiseIds(ref, praiseIds)
        : warmupColdigomPraiseIds(ref, praiseIds, timeout: timeout);
  }
}

final _warmupRunnerProvider = NotifierProvider<_WarmupRunner, int>(
  _WarmupRunner.new,
);

PraiseDetailDto _detailFor(String praiseId) {
  return PraiseDetailDto(
    id: praiseId,
    name: 'Comigo habita',
    number: '692',
    rhythm: 'Balada',
    materials: [
      MaterialDto(
        id: '$praiseId-m1',
        type: 'pdf',
        r2Key: 'assets/praises/$praiseId/m1.pdf',
      ),
    ],
  );
}

PraiseDetailDto _detailWithYoutube(String praiseId) {
  return PraiseDetailDto(
    id: praiseId,
    name: 'Comigo habita',
    number: '692',
    rhythm: 'Balada',
    materials: [
      MaterialDto(
        id: '$praiseId-m1',
        type: 'pdf',
        r2Key: 'assets/praises/$praiseId/m1.pdf',
      ),
      MaterialDto(
        id: '$praiseId-m2',
        type: 'youtube',
        url: 'https://youtu.be/abc',
      ),
    ],
  );
}

Louvor _coldigomLouvor({required String praiseId, String pdf = 'm1.pdf'}) {
  final relPath = 'assets/praises/$praiseId/$pdf';
  return Louvor.fromManifest(
    nome: 'Comigo habita',
    numero: '692',
    categoria: 'Partitura',
    classificacao: 'Balada',
    pdf: pdf,
    pdfId: encodePdfId(relPath),
    groupId: praiseId,
  );
}

/// Louvor cujo `pdfId` não decodifica para um praise — só o campo
/// [Louvor.praiseId] diz qual praise aquecer.
Louvor _louvorComPraiseId({required String praiseId}) => Louvor.fromManifest(
  nome: 'Firme nas promessas',
  numero: '010',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: 'https://coldigom.test/assets/praises/$praiseId/m.pdf',
  pdfId: 'legado-010',
  praiseId: praiseId,
  materialId: 'm',
);

void main() {
  group('ensureColdigomPraiseMaterialsCachedProvider', () {
    test('não propaga exceção de rede — apenas registra e retorna', () async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      addTearDown(() => debugPrint = originalDebugPrint);

      final datasource = _ControllableColdigomDatasource(
        (_) async => throw DioException(
          requestOptions: RequestOptions(),
          message: 'network down',
        ),
      );
      final louvor = _coldigomLouvor(praiseId: 'p1');

      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(ensureColdigomPraiseMaterialsCachedProvider)(louvor),
        completes,
      );

      expect(logs.any((l) => l.contains('[coldigom]')), isTrue);
    });

    test('não propaga timeout de rede — apenas registra e retorna', () {
      fakeAsync((async) {
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          logs.add(message ?? '');
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        final neverCompletes = Completer<PraiseDetailDto>();
        final datasource = _ControllableColdigomDatasource(
          (_) => neverCompletes.future,
        );
        final louvor = _coldigomLouvor(praiseId: 'p1');

        final container = ProviderContainer(
          overrides: [
            coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
          ],
        );
        addTearDown(container.dispose);

        var completed = false;
        unawaited(
          container
              .read(ensureColdigomPraiseMaterialsCachedProvider)(louvor)
              .then((_) => completed = true),
        );

        async.elapse(const Duration(seconds: 4));
        expect(completed, isFalse, reason: 'ainda dentro do timeout padrão');

        async.elapse(const Duration(seconds: 2));
        expect(completed, isTrue, reason: 'timeout padrão de 5s deve disparar');
        expect(logs.any((l) => l.contains('[coldigom]')), isTrue);
      });
    });

    test(
      'louvor com praiseId explícito aquece o praise e entra no cache Coldigom',
      () async {
        final datasource = _ControllableColdigomDatasource(
          (praiseId) async => _detailFor(praiseId),
        );
        final container = ProviderContainer(
          overrides: [
            coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
          ],
        );
        addTearDown(container.dispose);

        await container.read(ensureColdigomPraiseMaterialsCachedProvider)(
          _louvorComPraiseId(praiseId: 'pf'),
        );

        expect(datasource.calls, ['pf']);
        expect(
          container.read(coldigomPraiseMetaCacheProvider).keys,
          contains('pf'),
        );
        expect(
          container
              .read(coldigomLouvoresCacheProvider)
              .containsKey('legado-010'),
          isTrue,
        );
      },
    );

    test('não busca de novo quando o praise já tem meta em cache', () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailFor(praiseId),
      );
      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);
      container.read(coldigomPraiseMetaCacheProvider.notifier).mergeMeta({
        'pf': const ColdigomPraiseMetadata(name: 'Firme'),
      });

      await container.read(ensureColdigomPraiseMaterialsCachedProvider)(
        _louvorComPraiseId(praiseId: 'pf'),
      );

      expect(datasource.calls, isEmpty);
    });
  });

  group('warmupColdigomPraiseIds', () {
    test('pula praise que já tem meta em cache', () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailFor(praiseId),
      );
      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);
      container.read(coldigomPraiseMetaCacheProvider.notifier).mergeMeta({
        'p-quente': const ColdigomPraiseMetadata(name: 'Quente'),
      });

      await container.read(_warmupRunnerProvider.notifier).run([
        'p-quente',
        'p-frio',
      ]);

      expect(datasource.calls, ['p-frio']);
    });
    test('id cujo fetch falha não impede warmup dos demais ids', () async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      addTearDown(() => debugPrint = originalDebugPrint);

      final datasource = _ControllableColdigomDatasource((praiseId) async {
        if (praiseId == 'p-falha') {
          throw DioException(
            requestOptions: RequestOptions(),
            message: 'network down',
          );
        }
        return _detailFor(praiseId);
      });

      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      await container.read(_warmupRunnerProvider.notifier).run([
        'p-falha',
        'p-ok',
      ]);

      expect(datasource.calls, ['p-falha', 'p-ok']);
      expect(
        container
            .read(coldigomLouvoresCacheProvider)
            .values
            .any((l) => l.groupId == 'p-ok'),
        isTrue,
      );
      expect(logs.any((l) => l.contains('[coldigom]')), isTrue);
    });

    test('timeout customizado é respeitado (não usa o padrão de 5s)', () {
      fakeAsync((async) {
        final neverCompletes = Completer<PraiseDetailDto>();
        final datasource = _ControllableColdigomDatasource(
          (_) => neverCompletes.future,
        );

        final container = ProviderContainer(
          overrides: [
            coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
          ],
        );
        addTearDown(container.dispose);

        var completed = false;
        unawaited(
          container
              .read(_warmupRunnerProvider.notifier)
              .run(['p1'], timeout: const Duration(milliseconds: 200))
              .then((_) => completed = true),
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(completed, isFalse);

        async.elapse(const Duration(milliseconds: 200));
        expect(completed, isTrue);
      });
    });

    test('roda no máximo 3 em paralelo e aquece todos os ids', () async {
      final pending = <String, Completer<PraiseDetailDto>>{};
      var inFlight = 0;
      var maxInFlight = 0;

      final datasource = _ControllableColdigomDatasource((praiseId) {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        final completer = Completer<PraiseDetailDto>();
        pending[praiseId] = completer;
        return completer.future.whenComplete(() => inFlight--);
      });

      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      final ids = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7'];
      final done = container.read(_warmupRunnerProvider.notifier).run(ids);

      // Liberação em cascata: a cada resolução o pool puxa o próximo id.
      for (var resolved = 0; resolved < ids.length; resolved++) {
        await Future<void>.delayed(Duration.zero);
        expect(
          inFlight,
          lessThanOrEqualTo(3),
          reason: 'nunca mais de 3 fetchDetail em voo',
        );
        final next = pending.entries.firstWhere((e) => !e.value.isCompleted);
        next.value.complete(_detailFor(next.key));
      }

      await done;

      expect(maxInFlight, 3);
      expect(datasource.calls.toSet(), ids.toSet());
      expect(
        container.read(coldigomLouvoresCacheProvider).values.length,
        ids.length,
      );
    });

    test('uma falha no pool não impede os ids concorrentes', () async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          logs.add(message ?? '');
      addTearDown(() => debugPrint = originalDebugPrint);

      final datasource = _ControllableColdigomDatasource((praiseId) async {
        if (praiseId == 'p2') {
          throw DioException(
            requestOptions: RequestOptions(),
            message: 'network down',
          );
        }
        return _detailFor(praiseId);
      });

      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      await container.read(_warmupRunnerProvider.notifier).run([
        'p1',
        'p2',
        'p3',
        'p4',
      ]);

      final cached = container
          .read(coldigomLouvoresCacheProvider)
          .values
          .map((l) => l.groupId)
          .toSet();
      expect(cached, {'p1', 'p3', 'p4'});
      expect(logs.any((l) => l.contains('p2')), isTrue);
    });

    test('warmup também alimenta o cache de YouTube', () async {
      final datasource = _ControllableColdigomDatasource(
        (praiseId) async => _detailWithYoutube(praiseId),
      );

      final container = ProviderContainer(
        overrides: [
          coldigomRemoteDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      await container.read(_warmupRunnerProvider.notifier).run(['p1']);

      expect(container.read(coldigomYoutubeCacheProvider)['p1'], hasLength(1));
    });
  });
}
