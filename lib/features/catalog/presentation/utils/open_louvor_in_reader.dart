import 'dart:async';

import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/louvor.dart';
import '../../../coldigom/data/coldigom_praise_cache_warmup.dart';
import '../providers/louvor_pdf_download_provider.dart';
import '../providers/open_material_provider.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';

/// Abre [louvor] no leitor interno (`/leitor`) com resolve local-first.
///
/// Caminho `PdfMaterial` do `openMaterialProvider`, que traduz por
/// `presentMaterialOpenError` as exceções tipadas que escapam daqui. Quem chama
/// esta função direto (cards, sheet de faltantes) trata o erro por conta
/// própria — normalmente com [louvorPdfErrorMessage].
///
/// Sempre entra na lista ativa. Lista nova só pelo limpar da barra
/// ([CarouselBarTrailingActions] → Nova Lista).
///
/// Resolve o PDF e adiciona à playlist ativa **em paralelo** (A3): a rede
/// nunca deve travar a abertura do leitor. O warmup Coldigom roda
/// best-effort em segundo plano — nunca atrasa nem impede a navegação —, e
/// uma falha ao adicionar à playlist ativa (ex.: Isar indisponível) também
/// não impede abrir o PDF, que é a prioridade.
Future<void> openLouvorInReader({
  required WidgetRef ref,
  required BuildContext context,
  required Louvor louvor,
}) async {
  warmupColdigomInBackground(
    ref.read(ensureColdigomPraiseMaterialsCachedProvider),
    louvor,
  );

  final remotePath = LouvorPdfPath.fromLouvor(louvor);
  LocalPdfSource? source;

  await Future.wait<void>([
    _addLouvorToActivePlaylistSafely(ref, louvor.pdfId),
    ref
        .read(louvorPdfDownloadProvider.notifier)
        .resolveLouvorPdf(pdfId: louvor.pdfId, remotePath: remotePath)
        .then((value) {
          source = value;
        }),
  ]);

  if (!context.mounted) return;

  final location = ref
      .read(openPdfInReaderProvider)
      .call(
        pdfPath: source!.absolutePath,
        pdfId: louvor.pdfId,
        titulo: louvor.nome,
      );
  unawaited(context.push(location));
}

/// Adicionar à playlist ativa nunca deve impedir abrir o PDF (A3).
Future<void> _addLouvorToActivePlaylistSafely(
  WidgetRef ref,
  String pdfId,
) async {
  try {
    await ref.read(playlistsProvider.notifier).addLouvorToActivePlaylist(pdfId);
  } on Object catch (e) {
    debugPrint('[catalog] falha ao adicionar louvor à playlist ativa: $e');
  }
}

/// Resolve PDF do louvor — expõe erros tipados para UI.
Future<LocalPdfSource> resolveLouvorPdf({
  required WidgetRef ref,
  required Louvor louvor,
}) {
  final remotePath = LouvorPdfPath.fromLouvor(louvor);
  return ref
      .read(louvorPdfDownloadProvider.notifier)
      .resolveLouvorPdf(pdfId: louvor.pdfId, remotePath: remotePath);
}

/// Mensagem amigável para falhas de abertura/compartilhamento.
///
/// Delega à escada única ([classifyMaterialOpenFailure]): erros com mensagem
/// própria mostram a mensagem, o resto cai em [genericMessage].
String louvorPdfErrorMessage(Object error, String genericMessage) =>
    classifyMaterialOpenFailure(error).message ?? genericMessage;
