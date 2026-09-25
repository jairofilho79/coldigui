import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_list_entry.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_cluster_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/peanut_cluster_column.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

// «Clamo a ti»: Coletânea (casou) e PES (não casou). PDF + áudio em cada um,
// para o toque abrir o sheet (multi-material) e o «+» ir pelo editor.
final _col = catalogGroup(
  praiseId: 'col',
  number: '003',
  name: 'Clamo a ti',
  tags: const ['Coletânea · Clamor'],
  audioKinds: const {'k-audio': 'Playback'},
  groupId: 'G',
);
final _pes = catalogGroup(
  praiseId: 'pes',
  number: '003',
  name: 'Clamo a ti',
  tags: const ['GLTM', 'PES', 'Coletânea · Clamor'],
  audioKinds: const {'k-audio': 'Playback'},
  groupId: 'G',
);

final _entry = ClusterEntry(
  praiseGroupId: 'G',
  members: [
    ClusterMember(group: _col, matched: true),
    ClusterMember(group: _pes, matched: false),
  ],
);

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeActiveEditor> pumpCluster(
    WidgetTester tester, {
    Set<String> newIds = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final editor = FakeActiveEditor()..applyAddToActiveToState = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LouvorClusterCard(entry: _entry, newGroupIds: newIds),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return editor;
  }

  Finder lobe(int k) => find.byType(LouvorGroupCard).at(k);

  testWidgets('um gomo por membro, na ordem, com a etiqueta de cada um', (
    tester,
  ) async {
    await pumpCluster(tester);

    final cards = tester
        .widgetList<LouvorGroupCard>(find.byType(LouvorGroupCard))
        .toList();
    expect([for (final c in cards) c.group.groupId], ['col', 'pes']);
    expect(
      [for (final c in cards) c.lobePosition],
      [LobePosition.first, LobePosition.last],
    );
    expect(
      find.descendant(of: lobe(0), matching: find.text('Coletânea')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.text('GLTM · PES')),
      findsOneWidget,
    );
  });

  testWidgets('tocar no gomo esmaecido abre o sheet daquela versão', (
    tester,
  ) async {
    await pumpCluster(tester);

    await tester.tap(
      find.descendant(of: lobe(1), matching: find.text('#003 — Clamo a ti')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialSheet>(find.byType(MaterialSheet)).group.groupId,
      'pes',
    );
  });

  testWidgets('«+» do gomo esmaecido adiciona um material daquela versão', (
    tester,
  ) async {
    final editor = await pumpCluster(tester);

    await tester.tap(
      find.descendant(
        of: lobe(1),
        matching: find.byType(CarouselLouvorAddButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(editor.added, hasLength(1));
    expect([
      for (final m in _pes.materials) m.id,
    ], contains(editor.added.single.id));
  });

  testWidgets('esmaecido só no gomo que não casou', (tester) async {
    await pumpCluster(tester);

    bool isDim(Widget w) => w is Opacity && w.opacity == 0.45;
    expect(
      find.descendant(of: lobe(0), matching: find.byWidgetPredicate(isDim)),
      findsNothing,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.byWidgetPredicate(isDim)),
      findsOneWidget,
    );
  });

  testWidgets('«novo» só no gomo do id novo', (tester) async {
    await pumpCluster(tester, newIds: {'pes'});

    expect(
      find.descendant(of: lobe(0), matching: find.text(pt.searchResultNew)),
      findsNothing,
    );
    expect(
      find.descendant(of: lobe(1), matching: find.text(pt.searchResultNew)),
      findsOneWidget,
    );
  });

  testWidgets('gomos colados, sem sombra própria, numa coluna só', (
    tester,
  ) async {
    await pumpCluster(tester);

    expect(find.byType(PeanutClusterColumn), findsOneWidget);
    final column = tester.getRect(find.byType(PeanutClusterColumn));
    final first = tester.getRect(lobe(0));
    final last = tester.getRect(lobe(1));
    expect(first.bottom, last.top);
    expect(column.height, first.height + last.height);
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final decoration = box.decoration;
      if (decoration is ShapeDecoration) {
        expect(decoration.shadows ?? const <BoxShadow>[], isEmpty);
      }
    }
  });

  testWidgets('a coluna pinta uma sombra só, da silhueta dos dois gomos', (
    tester,
  ) async {
    await pumpCluster(tester);

    final column = tester.getRect(find.byType(PeanutClusterColumn));
    final first = tester.getRect(lobe(0)).shift(-column.topLeft);
    final last = tester.getRect(lobe(1)).shift(-column.topLeft);
    final shadowColor = AppColors.shadowMd.single.color;
    final render = tester.renderObject(find.byType(PeanutClusterColumn));
    expect(
      render,
      paints..path(
        color: shadowColor,
        includes: [first.center, last.center],
        excludes: [const Offset(1, 1)],
      ),
    );

    // Contando na pintura inteira (a coluna e os gomos): uma sombra só. Por
    // ARGB porque a cor volta do `Paint` em float e o `==` não casa.
    var shadowPaths = 0;
    expect(
      render,
      paints..everything((method, arguments) {
        if (method == #drawPath &&
            (arguments[1] as Paint).color.toARGB32() ==
                shadowColor.toARGB32()) {
          shadowPaths++;
        }
        return true;
      }),
    );
    expect(shadowPaths, 1);
  });
}
