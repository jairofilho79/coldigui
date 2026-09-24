import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/catalog/domain/usecases/normalize_legacy_material_ids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements LegacyIdStore {
  _FakeStore(
    this.name,
    this.ids, {
    this.collectThrows,
    this.rewriteThrows,
    this.rewriteResult = 1,
  });

  @override
  final String name;
  final Set<String> ids;
  final Object? collectThrows;
  final Object? rewriteThrows;
  final int rewriteResult;
  final received = <LegacyIdResolution>[];

  @override
  Future<Set<String>> collectLegacyIds() async {
    final error = collectThrows;
    if (error != null) throw error;
    return ids;
  }

  @override
  Future<int> rewrite(LegacyIdResolution resolution) async {
    final error = rewriteThrows;
    if (error != null) throw error;
    received.add(resolution);
    return rewriteResult;
  }
}

class _Resolver {
  _Resolver(this.answer, {this.error});

  final Map<String, String> answer;
  final Object? error;
  final calls = <Set<String>>[];

  Future<Map<String, String>> call(Iterable<String> ids) async {
    calls.add(ids.toSet());
    final e = error;
    if (e != null) throw e;
    return answer;
  }
}

void main() {
  final logs = <String>[];
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs.clear();
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() => debugPrint = originalDebugPrint);

  group('LegacyIdResolution.rewrite', () {
    final resolution = LegacyIdResolution(
      queried: {'l1', 'l2'},
      resolved: {'l1': 'x1'},
    );

    test('resolvido → id coldigom; desconhecido → null; outro → ele mesmo', () {
      expect(resolution.rewrite('l1'), 'x1');
      expect(resolution.rewrite('l2'), isNull);
      expect(resolution.isUnknown('l2'), isTrue);
      expect(
        resolution.rewrite('novo-depois-da-coleta'),
        'novo-depois-da-coleta',
      );
      expect(resolution.isUnknown('novo-depois-da-coleta'), isFalse);
    });
  });

  test('sem ids legados não há rede nem escrita', () async {
    final store = _FakeStore('a', const {});
    final resolver = _Resolver(const {});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [store],
      resolve: resolver.call,
    )();

    expect(outcome.legacy, 0);
    expect(outcome.pending, isFalse);
    expect(resolver.calls, isEmpty);
    expect(store.received, isEmpty);
  });

  test('junta os ids de todas as stores numa pergunta só', () async {
    final a = _FakeStore('a', {'l1', 'l2'}, rewriteResult: 2);
    final b = _FakeStore('b', {'l2', 'l3'}, rewriteResult: 3);
    final vazia = _FakeStore('vazia', const {});
    final resolver = _Resolver({'l1': 'x1', 'l3': 'x3'});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [a, b, vazia],
      resolve: resolver.call,
    )();

    expect(resolver.calls, [
      {'l1', 'l2', 'l3'},
    ]);
    expect(a.received.single.queried, {'l1', 'l2', 'l3'});
    expect(identical(a.received.single, b.received.single), isTrue);
    expect(vazia.received, isEmpty, reason: 'store sem legados não reescreve');
    expect(outcome.legacy, 3);
    expect(outcome.resolved, 2);
    expect(outcome.unknown, 1);
    expect(outcome.rewritten, 5, reason: 'soma das stores');
    expect(outcome.deferred, isFalse);
    expect(
      logs.last,
      '[legacy-ids] 3 legados: 2 resolvidos, 1 desconhecidos, '
      '5 registos reescritos',
    );
  });

  test('resolve falha → pendente, nenhuma store reescrita', () async {
    final a = _FakeStore('a', {'l1'});
    final resolver = _Resolver(const {}, error: StateError('sem rede'));

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [a],
      resolve: resolver.call,
    )();

    expect(outcome.pending, isTrue);
    expect(outcome.legacy, 1);
    expect(a.received, isEmpty);
  });

  test('uma store que falha (coleta ou escrita) não trava as outras', () async {
    final quebraColeta = _FakeStore('c', {
      'l9',
    }, collectThrows: StateError('x'));
    final quebraEscrita = _FakeStore('e', {
      'l1',
    }, rewriteThrows: StateError('y'));
    final boa = _FakeStore('b', {'l1'});
    final resolver = _Resolver({'l1': 'x1'});

    final outcome = await NormalizeLegacyMaterialIds(
      stores: [quebraColeta, quebraEscrita, boa],
      resolve: resolver.call,
    )();

    expect(resolver.calls.single, {'l1'});
    expect(boa.received, hasLength(1));
    expect(outcome.rewritten, 1);
  });

  test(
    'store adiada (manutenção ocupada) → deferred; as outras reescrevem',
    () async {
      final adiada = _FakeStore('offline', {
        'l1',
      }, rewriteThrows: const LegacyIdStoreDeferred('manutenção ocupada'));
      final boa = _FakeStore('b', {'l1'});
      final resolver = _Resolver({'l1': 'x1'});

      final outcome = await NormalizeLegacyMaterialIds(
        stores: [adiada, boa],
        resolve: resolver.call,
      )();

      expect(outcome.deferred, isTrue);
      expect(outcome.pending, isFalse);
      expect(outcome.rewritten, 1);
      expect(boa.received, hasLength(1));
      expect(
        logs,
        contains('[legacy-ids] offline: adiada (manutenção ocupada)'),
      );
      expect(logs, isNot(contains(contains('reescrita falhou'))));
    },
  );

  test('chave que não foi perguntada é ignorada', () async {
    final a = _FakeStore('a', {'l1'});
    final resolver = _Resolver({'l1': 'x1', 'intrusa': 'x9'});

    await NormalizeLegacyMaterialIds(stores: [a], resolve: resolver.call)();

    expect(a.received.single.resolved, {'l1': 'x1'});
  });
}
