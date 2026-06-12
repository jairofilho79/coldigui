import '../../../../core/constants/app_config.dart';

/// Tipo de origem resolvida para abertura via PDFx (UC-11 Fase 2.2).
enum PdfSourceKind {
  /// URL HTTP(S) — fetch via [Dio] + `PdfDocument.openData`.
  remoteUrl,

  /// Asset Flutter registrado no pubspec (`asset:path`).
  asset,

  /// Path absoluto no filesystem — `PdfDocument.openFile`.
  localFile,
}

/// Origem PDF resolvida a partir do query param `file`.
class ResolvedPdfSource {
  const ResolvedPdfSource({
    required this.kind,
    required this.value,
  });

  final PdfSourceKind kind;

  /// URL HTTP(S), path de asset Flutter ou path absoluto local.
  final String value;
}

/// Resolve o param [file] da rota `/leitor` para URL remota, asset ou arquivo.
///
/// Convenções:
/// - `https://...` / `http://...` → URL absoluta
/// - `/assets/...` ou `assets/...` → `${AppConfig.apiBaseUrl}` + path
/// - `asset:fixtures/sample.pdf` → asset Flutter registrado no pubspec
/// - path absoluto local → `PdfDocument.openFile`
class PdfSourceResolver {
  const PdfSourceResolver({this.apiBaseUrl = AppConfig.apiBaseUrl});

  static const String assetPrefix = 'asset:';

  final String apiBaseUrl;

  /// Resolve [filePath] bruto (query param) para [ResolvedPdfSource].
  ResolvedPdfSource resolve(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('filePath vazio');
    }

    if (trimmed.startsWith(assetPrefix)) {
      final assetPath = trimmed.substring(assetPrefix.length).trim();
      if (assetPath.isEmpty) {
        throw ArgumentError('asset path vazio');
      }
      return ResolvedPdfSource(
        kind: PdfSourceKind.asset,
        value: assetPath,
      );
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return ResolvedPdfSource(
        kind: PdfSourceKind.remoteUrl,
        value: trimmed,
      );
    }

    if (trimmed.startsWith('/') || trimmed.startsWith('assets/')) {
      if (_isAssetPath(trimmed)) {
        return ResolvedPdfSource(
          kind: PdfSourceKind.remoteUrl,
          value: _joinApiUrl(trimmed),
        );
      }
      return ResolvedPdfSource(
        kind: PdfSourceKind.localFile,
        value: trimmed,
      );
    }

    return ResolvedPdfSource(
      kind: PdfSourceKind.localFile,
      value: trimmed,
    );
  }

  bool _isAssetPath(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return normalized.startsWith('assets/');
  }

  String _joinApiUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    if (apiBaseUrl.isEmpty) {
      return normalizedPath;
    }
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return '$base$normalizedPath';
  }
}
