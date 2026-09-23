import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/ports/praise_entry_resolver.dart';
import 'package:coldigui/features/playlists/presentation/providers/praise_entry_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_kind_prefs_test_helpers.dart';
import '../../../helpers/praise_share_fixtures.dart';

void main() {
  final pdfId = praiseMaterialId('p1', 'partitura.pdf');
  final audioId = praiseMaterialId('p1', 'audio.mp3');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: pdfId, materialKindId: 'k-part')],
      audios: [
        praiseAudio(
          praiseId: 'p1',
          audioId: audioId,
          materialKindId: 'k-audio',
        ),
      ],
    ),
  ]);

  Future<PraiseEntryResolver> load(MaterialKindPrefs prefs) {
    final c = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(index),
        materialKindPrefsProvider.overrideWith(
          () => FixedMaterialKindPrefsNotifier(prefs),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c.read(praiseEntryResolverLoaderProvider)();
  }

  test('import com favoritos: grava o material do favorito', () async {
    final resolve = await load(
      MaterialKindPrefs.validated(
        kindIds: const ['k-audio'],
        updatedAt: DateTime.utc(2026, 9, 23),
      ),
    );
    expect(
      resolve('0a1'),
      PlaylistEntry(id: audioId, kind: MaterialKind.audio),
    );
  });

  test('import sem login: PDF principal', () async {
    final resolve = await load(MaterialKindPrefs.empty);
    expect(resolve('0a1'), PlaylistEntry(id: pdfId, kind: MaterialKind.pdf));
  });

  test('token desconhecido → null', () async {
    final resolve = await load(MaterialKindPrefs.empty);
    expect(resolve('fff'), isNull);
  });
}
