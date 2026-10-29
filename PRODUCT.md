# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Usuário primário: irmão da **equipe de louvor** (músico ou regente) que precisa **encontrar um louvor num acervo grande** (~2000 louvores, cada um com vários materiais: PDF, áudio, YouTube, no futuro chordpro, etc.) e **abrir o material certo**.

A **grande minoria** decora o número. O caminho normal de busca é **título, letra e texto**; número é atalho para quem já sabe. Qualquer UI que coloque o pad numérico como porta do app está errada.

Situação crítica: culto/ESF, muitas vezes sem internet estável — mas isso não autoriza esconder busca, biblioteca, filtros ou a variedade de materiais.

Não é a congregação inteira. Classes reais: **inglês**; **tablet**; **web**.

## Product Purpose

O **PLPCG** (Pesquisador de Louvores em Partitura, Cifra e Gestos) ajuda a equipe de louvor a **pesquisar, abrir e usar** os materiais básicos do louvor — inclusive offline, porque muita igreja e ESF não tem rede confiável.

Sucesso: no culto/ESF, a pessoa encontra o item certo (no acervo PLPCG **ou** Coldigom) e consegue lê-lo ou ouvi-lo sem sair do app e sem depender de rede na hora.

## Positioning

Um só app com **os dois acervos** (PLPCG e Coldigom): busca, leitor e listas no mesmo lugar. Um vizinho que só tenha um catálogo, só PDF num Drive, ou só a PWA antiga, não pode copiar isso com honestidade.

## Operating Context

- Acervo da ordem de **milhares de louvores**, não dezenas; cada louvor é um **grupo de materiais**, não um arquivo.
- Achar: título, letra, texto livre; número só se a pessoa já o souber.
- Usar: partitura, cifra, gestos, áudio, YouTube; filtros de material/arranjo (e metadados Coldigom: tom, ritmo, categoria, tags).
- Seleção da reunião: carousel, playlists, share, folheto — **além** da busca, nunca no lugar dela.
- Culto e ESF: urgência e rede ruim; a busca por texto continua sendo o mecanismo.
- Origem: projeto de irmãos da Igreja Cristã Maranata da Região do Triângulo Mineiro, servindo no Maanaim de Uberlândia-MG. **Não oficial** da ICM.
- Stack já decidida pelo código: Flutter 3, iOS, Android e web (`coldigui`).

## Capabilities and Constraints

**Há no produto:** busca (número, título; letra/texto é requisito de find); biblioteca; leitor PDF; player de áudio; YouTube; carousel; playlists e deep links; folheto; modo offline; i18n `pt` e `en`; catálogo dual PLPCG + Coldigom; Eventos, Social, Perfil.

**Interação (foco vigente):** abrir/+ um louvor **entra na lista ativa**, sem modal “lista atual ou nova”. Lista nova: limpar a barra → Nova Lista. O restante do modelo (filas PDF/áudio, palco, teclado) **não** está no recorte.

**Descartado (2026-08-18):** “Modo Culto” com teclado numérico como porta, 2 abas, e esconder Eventos/Social/busca/sheet. A minoria decora número; ~2000 louvores × N materiais precisam continuar pesquisáveis. `docs/guia-visual-modo-culto/` é hipótese morta.

**Fora do MVP:** upload admin (UC-13, flag desligada).

**Não fazer:** redesenhar a identidade visual; fingir endosso oficial da ICM; cobrar; fabricar depoimentos, números de usuários ou “parceria Coldigom” sem evidência.

**Aberto:** nenhum padrão de acessibilidade (WCAG, VoiceOver/TalkBack, Dynamic Type) foi fixado como requisito de produto.

## Brand Commitments

- Nome de produto: **PLPCG**. Repositório: `coldigui`.
- Gratuito. Não oficial da ICM. Seguir as orientações da Igreja.
- Voz institucional já publicada na tela Sobre (PT, não l10n): cumprimento “A Paz do Senhor Jesus”, serviço à equipe de louvor, convite à oração pelos envolvidos.
- Identidade visual incumbente (**Coletânea Digital**: vinho / creme / ouro) é restrição de preservação — refinar, não substituir. Paleta e tipo ficam no tema e, depois de T0.2, no `DESIGN.md`; não são decisão deste arquivo.

## Evidence on Hand

- Copy institucional: `lib/features/app_shell/presentation/pages/about_screen.dart`
- Especificação da migração e do acervo: `MAPEAMENTO_PLPCG_FLUTTER.md` (milhares de PDFs no R2)
- Use cases: `docs/use-cases/` (UC-01–UC-14, UC-16)
- Índice de features: `docs/features/FEATURE_INDEX.md`
- Contrato de áudio: `docs/features/AUDIO_BACKGROUND_CONTRACT.md`
- Acervo PLPCG via Worker/catálogo; Coldigom via API de produção documentada no README

Ausências que trabalho futuro **não deve inventar:** depoimentos, selo oficial ICM, métricas de uso, cases de congregação.

## Product Principles

1. **O catálogo é o produto.** ~2000 louvores, cada um com vários materiais (e mais tipos no futuro). UI que esconde busca, biblioteca ou a variedade de materiais falhou.
2. **Achar é texto primeiro.** Título, letra, busca livre. Número é atalho da minoria, nunca a porta.
3. **Dois acervos, uma busca.** PLPCG e Coldigom no mesmo fluxo de pesquisa; não duas apps coladas.
4. **Lista é de louvores, não de um tipo de arquivo.** Uma entrada = um louvor + o material escolhido (PDF, áudio, YouTube, chordpro…). Duas filas paralelas (PDF × áudio) não escalam.
5. **Não oficial, gratuito, alinhado à Igreja.** Nunca impersonar a ICM.
6. **pt e en; telefone, tablet e web são classes reais.**
