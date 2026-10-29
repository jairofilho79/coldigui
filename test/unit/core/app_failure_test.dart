import 'dart:io';

import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/features/audio_flags/domain/entities/remote_audio_flag.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio({
  int? statusCode,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final requestOptions = RequestOptions(path: '/x');
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response(requestOptions: requestOptions, statusCode: statusCode),
  );
}

RemotePlaylist _remotePlaylist() => RemotePlaylist(
  id: 'p1',
  nome: 'Ensaio',
  entries: const [],
  salva: true,
  favorita: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
  version: 1,
);

RemoteAudioFlag _remoteAudioFlag() => RemoteAudioFlag(
  id: 'f1',
  audioId: 'aud-1',
  positionMs: 1000,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
  version: 1,
);

void main() {
  group('AppFailure.from — DioException', () {
    test('sem response vira NetworkFailure', () {
      expect(
        AppFailure.from(_dio(type: DioExceptionType.connectionError)),
        isA<NetworkFailure>(),
      );
    });

    test('401 vira AuthFailure', () {
      expect(AppFailure.from(_dio(statusCode: 401)), isA<AuthFailure>());
    });

    test('403 vira AuthFailure', () {
      expect(AppFailure.from(_dio(statusCode: 403)), isA<AuthFailure>());
    });

    test('404 vira NotFoundFailure', () {
      expect(AppFailure.from(_dio(statusCode: 404)), isA<NotFoundFailure>());
    });

    test('409 vira ConflictFailure', () {
      expect(AppFailure.from(_dio(statusCode: 409)), isA<ConflictFailure>());
    });

    test('5xx sem classificação específica vira UnknownFailure', () {
      expect(AppFailure.from(_dio(statusCode: 500)), isA<UnknownFailure>());
    });
  });

  test('SocketException vira NetworkFailure', () {
    expect(
      AppFailure.from(const SocketException('falhou')),
      isA<NetworkFailure>(),
    );
  });

  test('PdfOfflineUnavailableException vira OfflineFailure', () {
    expect(
      AppFailure.from(const PdfOfflineUnavailableException(pdfId: 'x')),
      isA<OfflineFailure>(),
    );
  });

  test('PdfExternallyDeletedException vira NotFoundFailure', () {
    expect(
      AppFailure.from(const PdfExternallyDeletedException(pdfId: 'x')),
      isA<NotFoundFailure>(),
    );
  });

  test('PlaylistNotFoundException vira NotFoundFailure', () {
    expect(
      AppFailure.from(const PlaylistNotFoundException()),
      isA<NotFoundFailure>(),
    );
  });

  test('StorageUnavailableException vira StorageFailure', () {
    expect(
      AppFailure.from(const StorageUnavailableException('offline.put')),
      isA<StorageFailure>(),
    );
  });

  test('PdfStorageWriteException vira StorageFailure', () {
    expect(
      AppFailure.from(const PdfStorageWriteException('boom')),
      isA<StorageFailure>(),
    );
  });

  test('InsufficientDiskSpaceException vira StorageFailure', () {
    expect(
      AppFailure.from(
        const InsufficientDiskSpaceException(
          requiredBytes: 10,
          availableBytes: 0,
        ),
      ),
      isA<StorageFailure>(),
    );
  });

  test('PdfLocalCorruptedException vira StorageFailure', () {
    expect(
      AppFailure.from(const PdfLocalCorruptedException(pdfId: 'x')),
      isA<StorageFailure>(),
    );
  });

  test('PlaylistConflictException vira ConflictFailure', () {
    expect(
      AppFailure.from(PlaylistConflictException(_remotePlaylist())),
      isA<ConflictFailure>(),
    );
  });

  test('AudioFlagConflictException vira ConflictFailure', () {
    expect(
      AppFailure.from(AudioFlagConflictException(_remoteAudioFlag())),
      isA<ConflictFailure>(),
    );
  });

  test('erro não classificado vira UnknownFailure preservando a causa', () {
    final error = StateError('inesperado');
    final failure = AppFailure.from(error);
    expect(failure, isA<UnknownFailure>());
    expect(failure.cause, same(error));
  });

  test('cause preserva o erro original', () {
    final error = const PdfOfflineUnavailableException(pdfId: 'x');
    final failure = AppFailure.from(error);
    expect(failure.cause, same(error));
  });
}
