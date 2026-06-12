import 'package:flutter/material.dart';

import '../widgets/about_info_card.dart';

/// UC-14 — Tela Sobre ([RoutePaths.about]): Quem somos e Objetivo da aplicação.
///
/// Layout scrollável centralizado com `maxWidth: 896` (paridade
/// [LibraryScreen] / [HomeScreen]). Dois [AboutInfoCard]: "Quem somos"
/// (1 parágrafo) e "Objetivo" (2 parágrafos).
///
/// Conteúdo institucional fixo em PT — sem [AppLocalizations] nesta entrega.
///
/// Consumidores: [appRouterProvider] → [ShellScaffold.child] (aba Sobre,
/// índice 0 em [PlpcgBottomNavBar]).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const double _maxContentWidth = 896;

  static const _quemSomosBody =
      'A Paz do Senhor Jesus. Somos irmãos da Igreja Cristã Maranata '
      'da Região do Triângulo Mineiro e servimos no Maanaim de Uberlândia-MG. '
      'Esta aplicação não é oficial da ICM, mas o objetivo é ajudar a todos '
      'que estão no louvor ajudando na Obra. Seguindo as orientações da Igreja. '
      'De forma 100% gratuita.';

  static const _objetivoParagraph1 =
      'O objetivo da aplicação - chamada Pesquisador de Louvores em Partitura, '
      'Cifra e Gestos em gravuras - é ajudar aos irmãos da equipe de louvor '
      'com os materiais mais básicos pro louvor. Que seja fácil de pesquisar, '
      'consumir e que funcione offline, pois muita igrejas não tem internet ou '
      'é muito difícil o acesso em ESFs.';

  static const _objetivoParagraph2 =
      'Portanto, estejamos em oração por todos os irmãos que estão envolvidos '
      'nesse projeto. Quer seja diretamente no desenvolvimento da aplicação, '
      'quer seja na produção dos materiais, no uso/teste da aplicação e afins.';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            AboutInfoCard(
              title: 'Quem somos',
              paragraphs: [_quemSomosBody],
            ),
            SizedBox(height: 16),
            AboutInfoCard(
              title: 'Objetivo',
              paragraphs: [_objetivoParagraph1, _objetivoParagraph2],
            ),
          ],
        ),
      ),
    );
  }
}
