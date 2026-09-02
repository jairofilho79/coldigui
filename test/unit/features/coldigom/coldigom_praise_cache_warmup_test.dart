import 'dart:async';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_remote_datasource.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
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
    source: LouvorDataSource.coldigom,
  );
}

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
          container.read(ensureColdigomPraiseMaterialsCachedProvider)(louvor).then(
            (_) => completed = true,
          ),
        );

        async.elapse(const Duration(seconds: 4));
        expect(completed, isFalse, reason: 'ainda dentro do timeout padrão');

        async.elapse(const Duration(seconds: 2));
        expect(completed, isTrue, reason: 'timeout padrão de 5s deve disparar');
        expect(logs.any((l) => l.contains('[coldigom]')), isTrue);
      });
    });
  });

  group('warmupColdigomPraiseIds', () {
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

      await container
          .read(_warmupRunnerProvider.notifier)
          .run(['p-falha', 'p-ok']);

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
              .run(
                ['p1'],
                timeout: const Duration(milliseconds: 200),
              )
              .then((_) => completed = true),
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(completed, isFalse);

        async.elapse(const Duration(milliseconds: 200));
        expect(completed, isTrue);
      });
    });
  });
}
