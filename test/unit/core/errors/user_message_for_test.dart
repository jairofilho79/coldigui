import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/errors/user_message_for.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? statusCode}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  late AppLocalizations pt;
  late AppLocalizations en;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('DioException', () {
    test('erro de conexão vira mensagem de rede', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.connectionError)),
        pt.errorNoConnection,
      );
    });

    test('os três timeouts viram mensagem de timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          userMessageFor(pt, _dio(type)),
          pt.errorTimeout,
          reason: '$type',
        );
      }
    });

    test('5xx vira mensagem de servidor', () {
      for (final status in [500, 502, 503]) {
        expect(
          userMessageFor(
            pt,
            _dio(DioExceptionType.badResponse, statusCode: status),
          ),
          pt.errorServer,
          reason: '$status',
        );
      }
    });

    test('401 e 403 viram sessão expirada', () {
      for (final status in [401, 403]) {
        expect(
          userMessageFor(
            pt,
            _dio(DioExceptionType.badResponse, statusCode: status),
          ),
          pt.errorSessionExpired,
          reason: '$status',
        );
      }
    });

    test('404 e outros 4xx caem no genérico', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.badResponse, statusCode: 404)),
        pt.errorGeneric,
      );
    });

    test('cancelamento e erro desconhecido caem no genérico', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.cancel)),
        pt.errorGeneric,
      );
      expect(
        userMessageFor(pt, _dio(DioExceptionType.unknown)),
        pt.errorGeneric,
      );
    });
  });

  test('StorageUnavailableException vira aviso de armazenamento', () {
    expect(
      userMessageFor(pt, const StorageUnavailableException('playlists.insert')),
      pt.offlineStorageUnavailable,
    );
  });

  test('AuthUnauthorizedException vira sessão expirada', () {
    expect(
      userMessageFor(pt, AuthUnauthorizedException(401)),
      pt.errorSessionExpired,
    );
  });

  group('exceções de PDF já conhecidas', () {
    test('PDF removido do dispositivo vira texto traduzido', () {
      const error = PdfExternallyDeletedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), pt.pdfExternallyDeleted);
    });

    test('falha de download mantém a mensagem própria', () {
      const error = PdfFetchFailedException('Falha ao baixar o PDF');

      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });
  });

  group('causa embrulhada (Important 2)', () {
    test('PdfFetchFailedException com causa de rede vira erro de conexão', () {
      const error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: null,
      );
      final withCause = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.connectionError),
      );

      expect(userMessageFor(pt, withCause), pt.errorNoConnection);
      // Sem causa continua caindo na mensagem própria.
      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });

    test('causa de timeout vira mensagem de timeout', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.receiveTimeout),
      );

      expect(userMessageFor(pt, error), pt.errorTimeout);
    });

    test('causa 5xx vira mensagem de servidor', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.badResponse, statusCode: 503),
      );

      expect(userMessageFor(pt, error), pt.errorServer);
    });

    test('causa de armazenamento vira aviso de armazenamento', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: const StorageUnavailableException('offline.put'),
      );

      expect(userMessageFor(pt, error), pt.offlineStorageUnavailable);
    });

    // A3: a causa só ganha do wrapper quando diz algo. Um 404 (ou um
    // `cancel`/`unknown`) dentro do `PdfFetchFailedException` não é mais
    // informativo que "Falha ao baixar o PDF" — o genérico da causa não pode
    // atropelar a mensagem específica do wrapper.
    test('causa 404 não atropela a mensagem própria do wrapper', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.badResponse, statusCode: 404),
      );

      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });

    test('causa cancel/unknown não atropela a mensagem própria', () {
      for (final type in [DioExceptionType.cancel, DioExceptionType.unknown]) {
        expect(
          userMessageFor(
            pt,
            PdfFetchFailedException('Falha ao baixar o PDF', cause: _dio(type)),
          ),
          'Falha ao baixar o PDF',
          reason: '$type',
        );
      }
    });

    test('causa de rede continua ganhando do wrapper', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.connectionError),
      );

      expect(userMessageFor(pt, error), pt.errorNoConnection);
    });

    test('PdfLocalOpenFailure desembrulha a causa de rede', () {
      final error = PdfLocalOpenFailure(
        cause: _dio(DioExceptionType.connectionError),
        hasValidMagicBytes: null,
      );

      expect(userMessageFor(pt, error), pt.errorNoConnection);
    });
  });

  group('família PDF prefere chave l10n (Important 2)', () {
    test('PDF offline indisponível usa a chave, não o literal PT', () {
      const error = PdfOfflineUnavailableException(pdfId: 'p1');

      expect(userMessageFor(pt, error), pt.pdfOfflineUnavailableMessage);
      expect(userMessageFor(en, error), en.pdfOfflineUnavailableMessage);
      // Em inglês não pode sair a mensagem PT embutida na exceção.
      expect(userMessageFor(en, error), isNot(error.message));
    });

    test('PDF offline indisponível aponta para o download por tipo', () {
      const error = PdfOfflineUnavailableException(pdfId: 'p1');

      // «Baixar faltantes» saiu com a secção PLPCG (plano 3, Tarefa 10).
      expect(
        userMessageFor(pt, error),
        'Este PDF não foi baixado para uso offline. Conecte-se à internet ou '
        'baixe o tipo dele em Offline → Baixar para usar offline.',
      );
      expect(
        userMessageFor(en, error),
        'This PDF was not downloaded for offline use. Connect to the internet '
        'or download its type in Offline → Download for offline use.',
      );
      // O literal PT da exceção (mostrado direto pelo carrossel) idem.
      expect(error.message, userMessageFor(pt, error));
      expect(
        userMessageFor(pt, const PdfExternallyDeletedException(pdfId: 'p1')),
        contains('Offline → Baixar para usar offline'),
      );
    });

    test('leitura local falha usa a chave própria', () {
      const error = PdfLocalReadFailedException(pdfId: 'p1');

      expect(userMessageFor(en, error), en.pdfLocalReadFailedMessage);
    });

    test('PDF removido do dispositivo usa a chave própria (D.6)', () {
      const error = PdfExternallyDeletedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), pt.pdfExternallyDeleted);
      expect(userMessageFor(en, error), en.pdfExternallyDeleted);
    });

    test('PDF local corrompido usa a chave própria (D.6)', () {
      const error = PdfLocalCorruptedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), pt.pdfLocalCorrupted);
      expect(userMessageFor(en, error), en.pdfLocalCorrupted);
    });
  });

  group('fallback', () {
    test('exceção desconhecida nunca vaza o toString', () {
      final message = userMessageFor(pt, StateError('detalhe_interno_feio'));

      expect(message, pt.errorGeneric);
      expect(message, isNot(contains('detalhe_interno_feio')));
    });

    test('String crua também cai no genérico', () {
      expect(userMessageFor(pt, 'boom'), pt.errorGeneric);
    });
  });

  test('respeita o idioma recebido', () {
    expect(
      userMessageFor(en, _dio(DioExceptionType.connectionError)),
      en.errorNoConnection,
    );
    expect(
      userMessageFor(en, _dio(DioExceptionType.connectionError)),
      isNot(pt.errorNoConnection),
    );
  });
}
