import 'dart:async';

import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/louvor.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../pdf_opening/data/providers/pdf_opening_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';

/// Abre [louvor] no leitor interno (`/leitor`) com resolve local-first.
Future<void> openLouvorInReader({
  required WidgetRef ref,
  required BuildContext context,
  required Louvor louvor,
}) async {
  final remotePath = LouvorPdfPath.fromLouvor(louvor);
  final source = await ref.read(resolvePdfForReaderProvider)(
    pdfId: louvor.pdfId,
    remotePath: remotePath,
  );

  if (!context.mounted) return;

  final location = ref.read(openPdfInReaderProvider).call(
        pdfPath: source.absolutePath,
        pdfId: louvor.pdfId,
        titulo: louvor.nome,
      );
  unawaited(context.push(location));
  ref
      .read(playlistsProvider.notifier)
      .ensurePlaylistForLouvor(louvor.pdfId)
      .ignore();
}

/// Resolve PDF do louvor — expõe erros tipados para UI.
Future<LocalPdfSource> resolveLouvorPdf({
  required WidgetRef ref,
  required Louvor louvor,
}) {
  final remotePath = LouvorPdfPath.fromLouvor(louvor);
  return ref.read(resolvePdfForReaderProvider)(
    pdfId: louvor.pdfId,
    remotePath: remotePath,
  );
}

/// Mensagem amigável para falhas de abertura/compartilhamento.
String louvorPdfErrorMessage(Object error, String genericMessage) {
  return switch (error) {
    InvalidPdfPathException() => genericMessage,
    PdfOfflineUnavailableException(:final message) => message,
    PdfExternallyDeletedException(:final message) => message,
    PdfFetchFailedException(:final message) => message,
    _ => genericMessage,
  };
}
