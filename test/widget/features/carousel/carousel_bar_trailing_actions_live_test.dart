import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/live/presentation/providers/live_projection_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';
import '../../../support/test_overrides.dart';

class _Projecting extends LiveProjectionNotifier {
  @override
  LiveProjection? build() => LiveProjection(
    ownerName: 'Fulano',
    playlistId: 'p',
    name: 'Culto',
    entries: const [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)],
  );
}

void main() {
  testWidgets('seguindo: sem lixeira nem compartilhar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpApp(
      tester,
      const CarouselBarTrailingActions(),
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveProjectionProvider.overrideWith(_Projecting.new),
      ],
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.adaptive.share), findsNothing);
  });
}
