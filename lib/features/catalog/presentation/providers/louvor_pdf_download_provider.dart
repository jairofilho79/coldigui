import 'dart:async';

import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'louvor_pdf_download_state.dart';

/// Mapa `pdfId` → estado de download on-demand (loading + progresso).
final louvorPdfDownloadProvider = NotifierProvider<LouvorPdfDownloadNotifier,
    Map<String, LouvorPdfDownloadState>>(
  LouvorPdfDownloadNotifier.new,
);

/// Resolve PDF com feedback de progresso e guard contra downloads duplicados.
class LouvorPdfDownloadNotifier
    extends Notifier<Map<String, LouvorPdfDownloadState>> {
  final _inFlight = <String, Future<LocalPdfSource>>{};

  @override
  Map<String, LouvorPdfDownloadState> build() => const {};

  /// Resolve [pdfId] reutilizando o Future em andamento para o mesmo id.
  Future<LocalPdfSource> resolveLouvorPdf({
    required String pdfId,
    required String remotePath,
  }) {
    final existing = _inFlight[pdfId];
    if (existing != null) return existing;

    final future = _resolve(pdfId: pdfId, remotePath: remotePath);
    _inFlight[pdfId] = future;
    unawaited(
      future.whenComplete(() {
        _inFlight.remove(pdfId);
      }),
    );
    return future;
  }

  Future<LocalPdfSource> _resolve({
    required String pdfId,
    required String remotePath,
  }) async {
    Timer? progressLabelTimer;
    try {
      state = {
        ...state,
        pdfId: const LouvorPdfDownloadState(isLoading: true),
      };

      progressLabelTimer = Timer(const Duration(milliseconds: 500), () {
        final current = state[pdfId];
        if (current?.isLoading != true) return;
        state = {
          ...state,
          pdfId: current!.copyWith(showProgressLabel: true),
        };
      });

      return await ref.read(resolvePdfForReaderProvider).call(
            pdfId: pdfId,
            remotePath: remotePath,
            onProgress: (received, total) {
              final current = state[pdfId];
              if (current?.isLoading != true) return;
              state = {
                ...state,
                pdfId: current!.copyWith(
                  receivedBytes: received,
                  totalBytes: total > 0 ? total : null,
                ),
              };
            },
          );
    } finally {
      progressLabelTimer?.cancel();
      final next = Map<String, LouvorPdfDownloadState>.from(state);
      next.remove(pdfId);
      state = next;
    }
  }
}
