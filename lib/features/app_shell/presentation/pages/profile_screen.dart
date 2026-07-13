import 'package:flutter/material.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';

/// Hub do Perfil — atalhos para Sobre, Listas e Offline.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => goToShellDestination(context, RoutePaths.about),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Listas'),
              onTap: () => goToShellDestination(context, RoutePaths.playlists),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('Offline'),
              onTap: () => goToShellDestination(context, RoutePaths.offline),
            ),
          ],
        ),
      ),
    );
  }
}
