import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/louvor.dart';
import '../../catalog/domain/entities/louvor_data_source.dart';
import '../domain/utils/coldigom_praise_id.dart';
import 'coldigom_cache_writer.dart';
import 'datasources/coldigom_remote_datasource.dart';
import 'providers/coldigom_providers.dart';

/// Tempo máximo padrão para o warmup Coldigom aguardar a rede (A3).
///
/// Best-effort: nunca deve travar quem chama — ver [warmupColdigomPraiseIds]
/// e [ensureColdigomPraiseMaterialsCachedProvider].
const Duration coldigomWarmupDefaultTimeout = Duration(seconds: 5);

/// Quantos `fetchDetail` de warmup podem estar em voo ao mesmo tempo (A12).
///
/// O warmup do boot era serial: N ids × até 5 s cada, um depois do outro, com
/// a lista ativa esperando. Três em paralelo cortam a espera sem virar uma
/// rajada de N requisições contra a API.
const int coldigomWarmupConcurrency = 3;

/// Preenche caches Coldigom (PDF, áudio, cifra, meta e YouTube) para os
/// [praiseIds] do reload, com no máximo [coldigomWarmupConcurrency] em voo.
///
/// [timeout] limita **cada** busca de detalhe (não o conjunto) e nunca propaga
/// falha de rede para o chamador: um id que falha só registra e sai — os
/// concorrentes seguem.
Future<void> warmupColdigomPraiseIds(
  Ref ref,
  Iterable<String> praiseIds, {
  Duration timeout = coldigomWarmupDefaultTimeout,
}) async {
  final unique = {
    for (final id in praiseIds)
      if (id.isNotEmpty) id,
  };
  if (unique.isEmpty) return;

  final datasource = ref.read(coldigomRemoteDatasourceProvider);
  final writer = ref.read(coldigomCacheWriterProvider);

  final inFlight = <Future<void>>[];
  for (final praiseId in unique) {
    // Meta só entra no cache junto com o detalhe completo do praise (busca,
    // browse, hidratação, warmup): com ela, não há o que aquecer.
    if (ref.read(coldigomPraiseMetaCacheProvider).containsKey(praiseId)) {
      continue;
    }

    late Future<void> task;
    task = _warmupOnePraise(
      datasource,
      writer,
      praiseId,
      timeout,
    ).whenComplete(() => inFlight.remove(task));
    inFlight.add(task);

    // `Future.any` volta assim que o primeiro termina — e como `whenComplete`
    // já tirou o concluído da lista, a vaga está livre para o próximo id.
    if (inFlight.length >= coldigomWarmupConcurrency) {
      await Future.any(inFlight);
    }
  }

  await Future.wait(inFlight);
}

/// Um id do warmup: busca com timeout e funde; falha é registrada, não lançada.
///
/// Nunca completa com erro — é o que permite `Future.any`/`Future.wait` sobre o
/// pool sem que um id derrube os outros.
Future<void> _warmupOnePraise(
  ColdigomRemoteDatasource datasource,
  ColdigomCacheWriter writer,
  String praiseId,
  Duration timeout,
) async {
  try {
    final detail = await datasource.fetchDetail(praiseId).timeout(timeout);
    writer.mergePraiseDetail(praiseId, detail);
  } on Object catch (e) {
    debugPrint('[coldigom] warmup falhou para $praiseId: $e');
  }
}

/// Dispara o warmup do praise em background, sem atrasar nem impedir a
/// navegação (A3).
///
/// Recebe a função já lida do [ensureColdigomPraiseMaterialsCachedProvider]
/// porque os dois chamadores têm refs de tipos diferentes (`WidgetRef` ao abrir
/// da Home, `Ref` no provider do carousel). O timeout **não** é reaplicado
/// aqui: ele já está dentro do provider, e duplicá-lo só dobraria a espera.
void warmupColdigomInBackground(
  Future<void> Function(Louvor) ensureMaterialsCached,
  Louvor louvor,
) {
  unawaited(
    ensureMaterialsCached(louvor).catchError((Object e) {
      debugPrint('[coldigom] warmup falhou: $e');
    }),
  );
}

/// Busca sob demanda os materiais do praise ao abrir o leitor (áudio/cifra/letra no sheet).
///
/// Best-effort: nunca lança para o chamador, mesmo com falha/timeout de
/// rede (A3) — apenas registra via [debugPrint] e retorna.
final ensureColdigomPraiseMaterialsCachedProvider =
    Provider<Future<void> Function(Louvor)>((ref) {
      return (Louvor louvor) async {
        final praiseId =
            louvor.praiseId ?? coldigomPraiseIdFromPdfId(louvor.pdfId);
        if (praiseId == null) return;

        // Só materiais Coldigom nativos entram no cache Coldigom.
        if (louvor.source == LouvorDataSource.coldigom) {
          ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
            louvor,
          ]);
        }

        if (ref.read(coldigomPraiseMetaCacheProvider).containsKey(praiseId)) {
          return;
        }

        await _warmupOnePraise(
          ref.read(coldigomRemoteDatasourceProvider),
          ref.read(coldigomCacheWriterProvider),
          praiseId,
          coldigomWarmupDefaultTimeout,
        );
      };
    });
