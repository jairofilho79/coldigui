import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_view_settings_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FullscreenFixedNotifier extends ReaderFullscreenNotifier {
  _FullscreenFixedNotifier(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

class _SettingsFixedNotifier extends PdfReaderViewSettingsNotifier {
  _SettingsFixedNotifier(this._settings);

  final PdfReaderViewSettings _settings;

  @override
  PdfReaderViewSettings build() => _settings;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer buildContainer({
    required bool fullscreen,
    required PdfReaderViewSettings settings,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        readerFullscreenProvider.overrideWith(
          () => _FullscreenFixedNotifier(fullscreen),
        ),
        pdfReaderViewSettingsProvider.overrideWith(
          () => _SettingsFixedNotifier(settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('pdfReaderEffectiveFitModeProvider', () {
    test('fora do fullscreen usa a preferência salva', () {
      final container = buildContainer(
        fullscreen: false,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageFit,
          spreadEnabled: true,
        ),
      );

      expect(
        container.read(pdfReaderEffectiveFitModeProvider),
        PdfFitMode.pageFit,
      );
    });

    test('em fullscreen força page-width mesmo com preferência page-fit', () {
      final container = buildContainer(
        fullscreen: true,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageFit,
          spreadEnabled: true,
        ),
      );

      expect(
        container.read(pdfReaderEffectiveFitModeProvider),
        PdfFitMode.pageWidth,
      );
    });
  });

  // Important 1 (onda 4): pdfrx 2.4.4 só enquadra UMA página por vez
  // (`calcMatrixFitWidthForPage`/`calcMatrixFitHeightForPage` — não existe
  // `calcMatrixFitWidthForRect`/equivalente para a linha nesta versão).
  // Enquanto o fit efetivo for `pageWidth`, o spread some (a 2ª página do
  // par ficaria fora da viewport); volta assim que o fit efetivo for
  // `pageFit`.
  group('pdfReaderEffectiveSpreadEnabledProvider', () {
    test('preferência desligada permanece desligada', () {
      final container = buildContainer(
        fullscreen: false,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageFit,
          spreadEnabled: false,
        ),
      );

      expect(container.read(pdfReaderEffectiveSpreadEnabledProvider), isFalse);
    });

    test('preferência ligada com fit page-fit fica ativa', () {
      final container = buildContainer(
        fullscreen: false,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageFit,
          spreadEnabled: true,
        ),
      );

      expect(container.read(pdfReaderEffectiveSpreadEnabledProvider), isTrue);
    });

    test('preferência ligada com fit page-width fica desativada '
        '(page-width enquadraria só 1 página do par)', () {
      final container = buildContainer(
        fullscreen: false,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageWidth,
          spreadEnabled: true,
        ),
      );

      expect(container.read(pdfReaderEffectiveSpreadEnabledProvider), isFalse);
    });

    test('preferência ligada + fit page-fit, mas fullscreen força '
        'page-width -> desativada', () {
      final container = buildContainer(
        fullscreen: true,
        settings: const PdfReaderViewSettings(
          fitMode: PdfFitMode.pageFit,
          spreadEnabled: true,
        ),
      );

      expect(container.read(pdfReaderEffectiveSpreadEnabledProvider), isFalse);
    });
  });
}
