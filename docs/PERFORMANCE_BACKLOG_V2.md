# Backlog de Performance v2 — coldigui (PLPCG Flutter)

**Criado em:** 2026-06-18  
**Origem:** Observação em dispositivo físico — Xiaomi Pad 6 (Snapdragon 870), Android  
**Sintoma:** ~15 FPS aparente durante troca de abas; animações da bottom bar travadas  
**Referência anterior:** `docs/PERFORMANCE_BACKLOG.md` (itens #1–#7)

> Este documento foca exclusivamente em **fluência de animações e rendering em hardware de médio porte**.  
> Os itens do backlog anterior (#1–#7) permanecem válidos e independentes.

---

## Diagnóstico — Causa Raiz Identificada

A queda para ~15 FPS na troca de abas é causada por uma **combinação de fatores que ocorrem simultaneamente** em cada troca:

| Fator | Custo GPU/CPU | Onde |
|-------|---------------|------|
| 3× `MaskFilter.blur` no `LightBeamPainter` | **Muito Alto** | `light_beam.dart` |
| `AnimatedTheme` interpolando ThemeData completo | **Alto** | `plpcg_bottom_nav_bar.dart` |
| 5 itens animando ao mesmo tempo sem `RepaintBoundary` | **Alto** | `plpcg_bottom_nav_bar.dart` |
| `TextPainter.layout()` em cada frame da animação | **Médio** | `_NavLabel._beamWidth()` |
| `AnimationController.repeat()` com boxShadow/blur contínuo | **Médio** | `golden_tagged_container.dart` |
| Duração de 380ms aumenta janela de exposição ao jank | Amplificador | `animationDuration` |
| GoRouter `ShellRoute` simples reconstrói tela a cada troca de aba | **Médio** | `app_router.dart` |

### Por que o Xiaomi Pad 6 sofre mais

O Snapdragon 870 tem GPU Adreno 650 competente, mas o gargalo aqui não é velocidade bruta: é **custo de rasterização com blur**. O `MaskFilter.blur` no Skia/Impeller força o Flutter a:

1. Criar uma camada offscreen para cada blur
2. Aplicar convolução gaussiana nessa camada
3. Compor o resultado de volta na cena principal

Com 3 blurs no `LightBeamPainter`, e o painter sendo executado em cada frame da animação de escala (porque o `LightBeam` está dentro de um `AnimatedScale` + `AnimatedOpacity` **sem RepaintBoundary**), o custo se multiplica. O LightBeam do AppBar (sempre visível, 170px) adiciona mais 3 blurs constantes.

---

## Priorização

| # | Item | Impacto FPS | Esforço | Arquivo principal |
|---|------|-------------|---------|-------------------|
| A1 | Substituir blur no `LightBeamPainter` por gradient estático | **Crítico** | Baixo | `light_beam.dart` |
| A2 | Isolar `LightBeam` e bottom bar com `RepaintBoundary` | **Crítico** | Baixo | `light_beam.dart`, `plpcg_bottom_nav_bar.dart` |
| A3 | Substituir `AnimatedTheme` por `TweenAnimationBuilder<Color>` | **Alto** | Baixo | `plpcg_bottom_nav_bar.dart` |
| A4 | Reduzir `animationDuration` de 380ms → 200ms | **Alto** | Trivial | `plpcg_bottom_nav_bar.dart` |
| A5 | Cachear `TextPainter.layout()` fora do `build()` | **Médio** | Baixo | `plpcg_bottom_nav_bar.dart` |
| B1 | Desativar glow `repeat()` em idle ou reduzir shadow | **Médio** | Baixo | `golden_tagged_container.dart` |
| B2 | Migrar `ShellRoute` para `StatefulShellRoute` (preservar estado das abas) | **Médio** | Médio | `app_router.dart` |
| B3 | Consolidar animações simultâneas da bottom bar num único `AnimationController` | **Médio** | Médio | `plpcg_bottom_nav_bar.dart` |
| C1 | Adicionar `RepaintBoundary` no `LightBeam` do `PlpcgAppBarTitle` | Baixo | Trivial | `plpcg_app_bar_title.dart` |
| C2 | Verificar e habilitar `Impeller` no Android (já padrão no Flutter 3.19+) | Baixo | Trivial | `android/app/src/main/AndroidManifest.xml` |

**Ordem sugerida:** A1 → A2 → A3 → A4 → A5 → B1 → B2 → B3 → C1 → C2

---

## #A1 — Substituir `MaskFilter.blur` no `LightBeamPainter` por gradiente estático

**Impacto:** Crítico  
**Esforço:** Baixo  
**Arquivo:** `lib/core/widgets/light_beam.dart`

### Problema

`LightBeamPainter.paint()` executa **3 operações de blur** em cada chamada:

```dart
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),   // halo externo
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5), // núcleo radial
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),   // brilho inferior
```

Cada `MaskFilter.blur` força o Skia/Impeller a criar uma **camada offscreen** (render pass adicional), aplicar convolução gaussiana e compor de volta. Em hardware de médio porte, cada blur custa ~2–4ms de GPU. Com 3 blurs × 2 instâncias visíveis (AppBar + aba ativa) = ~6 blurs por frame = ~12–24ms de GPU *só para o LightBeam*, deixando menos de 4ms por frame para o resto (budget de 60 FPS = 16.6ms).

O efeito visual de "glow difuso" que o blur cria **pode ser reproduzido com gradientes radiais de alta qualidade** sem nenhuma operação de blur — a diferença é imperceptível em telas AMOLED de tablet.

### Solução recomendada

Remover todos os `MaskFilter.blur`. Compensar visualmente com:

1. Gradiente radial mais suave com mais color stops (ex.: 5–6 stops em vez de 4)
2. Aumentar levemente a opacidade dos stops intermediários (o blur estava "amolecendo" a borda)
3. Elipse externa com gradiente radial de halo (em vez de blur no oval)

```dart
// Antes (caro)
canvas.drawOval(ovalRect, Paint()
  ..color = AppColors.gold.withValues(alpha: 0.28)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

// Depois (grátis)
canvas.drawOval(ovalRect, Paint()
  ..shader = ui.Gradient.radial(
    center, radius,
    [AppColors.gold.withValues(alpha: 0.22), Colors.transparent],
    [0.0, 1.0],
  ));
```

4. Opcional: marcar `shouldRepaint` para retornar `false` explicitamente (já está correto no código atual — manter).

### Critério de aceite

- Zero chamadas a `MaskFilter.blur` em `LightBeamPainter`
- Efeito visual de feixe dourado preservado (comparação visual no emulador/dispositivo)
- `flutter test test/widget/` passa (golden tests de AppBar/bottom bar, se houver)
- Flutter Profiler: GPU time por frame na home/troca de aba cai ≥ 30%

---

## #A2 — `RepaintBoundary` no `LightBeam` e na bottom bar

**Impacto:** Crítico (junto com #A1)  
**Esforço:** Baixo  
**Arquivos:** `lib/core/widgets/light_beam.dart`, `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart`

### Problema

O `LightBeam` é renderizado dentro de `AnimatedScale` + `AnimatedOpacity` na bottom bar. Sem `RepaintBoundary`:

1. A cada frame da animação, **todo o item** (ícone + label + LightBeam) é repintado
2. A bottom bar inteira (todos os 5 itens) é repintada quando qualquer item muda
3. O `LightBeam` do AppBar não tem boundary — qualquer rebuild do AppBar o repinta

Com `RepaintBoundary`:
- O `LightBeam` é rasterizado **uma vez** e o bitmap é cacheado na GPU
- O Flutter só re-usa o bitmap cacheado durante escala/opacidade (operações de compositor, não de rasterização)

> **Nota:** O item #A1 (remover blur) é prerequisito — sem ele, o `RepaintBoundary` ainda força rasterização cara. Juntos, eles eliminam o custo.

### Solução recomendada

1. Em `LightBeam.build()`:

```dart
@override
Widget build(BuildContext context) {
  return RepaintBoundary(
    child: CustomPaint(
      size: Size(width, height),
      painter: const LightBeamPainter(),
    ),
  );
}
```

2. Em `PlpcgBottomNavBar`: envolver cada `_PlpcgBottomNavItem` em `RepaintBoundary`:

```dart
for (var i = 0; i < destinations.length; i++)
  Expanded(
    child: RepaintBoundary(
      child: _PlpcgBottomNavItem(
        destination: destinations[i],
        selected: i == selectedIndex,
        onTap: () => onDestinationSelected(i),
      ),
    ),
  ),
```

### Critério de aceite

- DevTools "Highlight Repaints" não mostra piscada da barra inteira ao trocar aba
- Cada item pisca individualmente, não o bloco todo
- Nenhuma regressão visual

---

## #A3 — Substituir `AnimatedTheme` por `TweenAnimationBuilder<Color>`

**Impacto:** Alto  
**Esforço:** Baixo  
**Arquivo:** `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart`

### Problema

`AnimatedTheme` interpola **ThemeData completo** (centenas de propriedades) a cada frame para animar *apenas a cor e o tamanho do ícone*:

```dart
return AnimatedTheme(
  duration: duration,
  data: Theme.of(context).copyWith(
    iconTheme: IconThemeData(
      color: selected ? AppColors.placeholder : AppColors.textLight.withValues(alpha: 0.52),
      size: selected ? 26 : 20,
    ),
  ),
  child: Icon(destination.icon),
);
```

`ThemeData.lerp()` é chamada em cada frame (a ~60 Hz por 380ms = ~22 chamadas), cada uma alocando e interpolando um `ThemeData` completo. É o equivalente a recriar o tema do app inteiro 22 vezes por troca de aba.

### Solução recomendada

Substituir por `TweenAnimationBuilder` animando diretamente as duas propriedades relevantes:

```dart
return TweenAnimationBuilder<double>(
  tween: Tween(begin: selected ? 0.0 : 1.0, end: selected ? 1.0 : 0.0),
  duration: duration,
  curve: PlpcgBottomNavBar._animationCurve,
  builder: (context, t, _) {
    final color = Color.lerp(
      AppColors.textLight.withValues(alpha: 0.52),
      AppColors.placeholder,
      t,
    )!;
    final size = lerpDouble(20, 26, t)!;
    return Icon(destination.icon, color: color, size: size);
  },
);
```

### Critério de aceite

- Transição visual de cor/tamanho do ícone idêntica à anterior
- Nenhum `AnimatedTheme` remanescente em `_NavIcon`
- `flutter test test/widget/features/app_shell/` passa

---

## #A4 — Reduzir `animationDuration` de 380ms para 200ms

**Impacto:** Alto (percepção imediata de fluidez)  
**Esforço:** Trivial  
**Arquivo:** `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart`

### Problema

```dart
static const Duration animationDuration = Duration(milliseconds: 380);
```

Em dispositivos com jank (15 FPS), 380ms de animação produz uma sensação ainda mais lenta porque cada "frame" visível representa saltos maiores de progresso. Além disso, 380ms é longo mesmo em 60 FPS — bottom bars de referência (Material 3 NavigationBar) usam 200–250ms.

Reduzir a duração:
- Encurta a janela de tempo durante a qual o jank é perceptível
- Produz resposta mais ágil ao toque
- Reduz o número de frames que precisam ser renderizados (~22 frames → ~12 frames a 60 FPS)

### Solução recomendada

```dart
static const Duration animationDuration = Duration(milliseconds: 200);
```

Considerar também trocar `Curves.easeInOut` por `Curves.easeOut` — mais natural para interações de toque (rápido no início, suave no final).

### Critério de aceite

- Resposta ao toque percebida como mais ágil em teste no dispositivo físico
- `MediaQuery.disableAnimationsOf` continua retornando `Duration.zero` corretamente

---

## #A5 — Cachear `TextPainter.layout()` fora do `build()`

**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo:** `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart`

### Problema

`_NavLabel._beamWidth()` é chamada **dentro do `build()`**:

```dart
@override
Widget build(BuildContext context) {
  final beamWidth = _beamWidth(_activeStyle); // ← TextPainter.layout() aqui
  // ...
}
```

`TextPainter.layout()` é uma operação **síncrona de layout de texto** que não é trivial. Ela é executada a cada rebuild do `_NavLabel` — que ocorre ~5 vezes por troca de aba (5 items rebuildando) × ~22 frames = ~110 `TextPainter.layout()` por animação completa.

O label é `String` constante. A largura nunca muda.

### Solução recomendada

Transformar `_NavLabel` em `StatefulWidget` e cachear em `initState`:

```dart
class _NavLabel extends StatefulWidget {
  // ...
}

class _NavLabelState extends State<_NavLabel> {
  late final double _beamWidth;

  @override
  void initState() {
    super.initState();
    _beamWidth = _computeBeamWidth(widget.label, _NavLabel._activeStyle);
  }

  static double _computeBeamWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return (painter.width * 1.35).clamp(36.0, 96.0);
  }

  @override
  Widget build(BuildContext context) {
    // usar _beamWidth em vez de chamar _beamWidth()
  }
}
```

### Critério de aceite

- `_beamWidth` nunca é calculada dentro de `build()`
- Largura do LightBeam inalterada visualmente
- `flutter test` passa

---

## #B1 — Desativar ou reduzir `GoldenTaggedContainer` glow em idle

**Impacto:** Médio  
**Esforço:** Baixo  
**Arquivo:** `lib/core/widgets/golden_tagged_container.dart`

### Problema

Quando `glowEnabled = true`, um `AnimationController.repeat(reverse: true)` anima `boxShadow` com dois `BoxShadow` de `blurRadius` 16 e 24 continuamente:

```dart
_glowController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 2400),
)..repeat(reverse: true);
```

`BoxShadow` com `blurRadius` grande aciona Skia para calcular sombra difusa a cada frame, mesmo durante idle (sem interação do usuário). Isso consome CPU/GPU desnecessariamente enquanto o usuário navega pela Home — a cada 2400ms, 144 frames são gerados só para pulsar a borda do campo de busca.

### Solução recomendada

**Opção A (recomendada):** Substituir a animação contínua por uma transição única ao focar:
- Sem `repeat()` — apenas fade-in/out ao ganhar/perder foco

**Opção B (paliativa):** Reduzir `blurRadius` para ≤ 8px (custa menos à GPU) e manter o repeat mas em duração maior (4000ms) para reduzir frequência de atualização.

**Opção C:** Checar `MediaQuery.disableAnimationsOf` e, se verdadeiro, usar apenas o fallback estático (já implementado no `boxShadow` estático quando `_glowAnimation == null`). Extender essa lógica para dispositivos com `MediaQuery.highContrastOf` ou para uma `FeatureFlag.reducedAnimations`.

### Critério de aceite

- Sem `AnimationController.repeat()` ativo durante scroll/navegação entre abas
- Efeito visual de "glow ativo" preservado ao focar na busca
- `flutter test test/widget/features/catalog/` passa

---

## #B2 — Migrar `ShellRoute` para `StatefulShellRoute` (preservar estado das abas)

**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo:** `lib/core/routing/app_router.dart`

### Problema

O GoRouter usa `ShellRoute` simples:

```dart
ShellRoute(
  builder: (context, state, child) => ShellScaffold(child: child),
  routes: [...],
),
```

Com `ShellRoute` simples, cada troca de aba com `context.go()` **destrói e reconstrói** a tela anterior. Isso significa:

- Ao voltar para a Home, a `HomeScreen` é recriada do zero
- Os providers ligados ao ciclo de vida da tela são redispostos e recriados
- A `LibraryScreen` com seu pipeline de ~4600 louvores é reinicializada
- O scroll position é perdido

`StatefulShellRoute` (disponível no GoRouter 13+) mantém as telas em memória com `AutomaticKeepAliveClientMixin` interno, evitando rebuild completo.

### Solução recomendada

Migrar para `StatefulShellRoute.indexedStack`:

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      ShellScaffold(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: RoutePaths.about, ...)]),
    StatefulShellBranch(routes: [GoRoute(path: RoutePaths.library, ...)]),
    StatefulShellBranch(routes: [GoRoute(path: RoutePaths.home, ...)]),
    StatefulShellBranch(routes: [GoRoute(path: RoutePaths.offline, ...)]),
    StatefulShellBranch(routes: [GoRoute(path: RoutePaths.playlists, ...)]),
  ],
),
```

`ShellScaffold` precisa ser adaptado para receber `StatefulNavigationShell` e chamar `navigationShell.goBranch(index)` em vez de `context.go(path)`.

> **Atenção:** O `reader` (`/leitor`) deve continuar como rota separada fora do `StatefulShellRoute`, ou como sub-rota de uma branch, para manter o comportamento de ocultar a bottom bar.

> **Atenção:** Verificar se `readerFullscreenProvider` e `CarouselChips` continuam funcionando corretamente com `navigationShell` — eles dependem de `GoRouterState.of(context)`.

### Critério de aceite

- Troca de aba não reconstrói `HomeScreen`/`LibraryScreen`
- Scroll position preservado ao voltar para uma aba
- Providers da UI não são redispostos ao trocar aba
- Testes de integração de navegação passam
- Leitor PDF continua ocultando a bottom bar corretamente

---

## #B3 — Consolidar animações simultâneas em único `AnimationController`

**Impacto:** Médio  
**Esforço:** Médio  
**Arquivo:** `lib/features/app_shell/presentation/widgets/plpcg_bottom_nav_bar.dart`

### Problema

Cada `_PlpcgBottomNavItem` usa 5–6 widgets animados independentes:

1. `AnimatedScale` (item inteiro)
2. `AnimatedContainer` (tamanho do ícone)
3. `AnimatedOpacity` (opacidade do SVG logo)
4. `AnimatedTheme` → `TweenAnimationBuilder` após #A3 (cor/tamanho do ícone Material)
5. `AnimatedOpacity` (LightBeam)
6. `AnimatedScale` (LightBeam)
7. `AnimatedDefaultTextStyle` (label)

Cada widget animado cria seu próprio `AnimationController` internamente. Com 5 itens na barra, isso resulta em até **35 controllers ativos** durante a animação, todos chamando `setState` de forma independente por frame.

### Solução recomendada

Refatorar `_PlpcgBottomNavItem` para `StatefulWidget` com **um único `AnimationController`** e derivar todas as propriedades animadas via `Animation.drive()`:

```dart
class _PlpcgBottomNavItem extends StatefulWidget { ... }

class _PlpcgBottomNavItemState extends State<_PlpcgBottomNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _iconSize;
  late final Animation<double> _opacity;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PlpcgBottomNavBar.animationDuration);
    if (widget.selected) _ctrl.value = 1.0;

    final curve = CurvedAnimation(parent: _ctrl, curve: PlpcgBottomNavBar._animationCurve);
    _scale = Tween(begin: _inactiveScale, end: _activeScale).animate(curve);
    _iconSize = Tween(begin: 20.0, end: 26.0).animate(curve);
    _opacity = Tween(begin: 0.52, end: 1.0).animate(curve);
    _labelOpacity = Tween(begin: 0.0, end: 1.0).animate(curve);
  }

  @override
  void didUpdateWidget(_PlpcgBottomNavItem old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      widget.selected ? _ctrl.forward() : _ctrl.reverse();
    }
  }
}
```

Isso reduz de ~35 controllers para **5 controllers** (um por item), e cada item dispara apenas um `addListener` por frame em vez de 7.

### Critério de aceite

- Comportamento visual idêntico ao atual
- DevTools mostra ≤ 5 `AnimationController` ativos durante troca de aba (em vez de ~35)
- `flutter test test/widget/features/app_shell/` passa

---

## #C1 — `RepaintBoundary` no `LightBeam` do `PlpcgAppBarTitle`

**Impacto:** Baixo  
**Esforço:** Trivial  
**Arquivo:** `lib/core/widgets/plpcg_app_bar_title.dart`

### Problema

O `LightBeam(width: 170, height: 16)` na AppBar não tem `RepaintBoundary`. Qualquer rebuild do AppBar (ex.: mudança de rota, rebuild do `ShellScaffold`) repinta o painter. Após o #A1, o custo é baixo, mas ainda desnecessário.

### Solução recomendada

O `RepaintBoundary` já foi adicionado ao `LightBeam` em #A2. Este item é automaticamente resolvido se #A2 for implementado como sugerido.

**Ação:** Verificar após #A2 se o `LightBeam` no AppBar está coberto. Marcar como concluído junto com #A2.

---

## #C2 — Verificar Impeller habilitado no Android

**Impacto:** Baixo–Médio  
**Esforço:** Trivial  
**Arquivo:** `android/app/src/main/AndroidManifest.xml`

### Problema

O Impeller (backend de renderização do Flutter 3.19+) é padrão no iOS desde Flutter 3.10 e no Android desde Flutter 3.22. Contudo, algumas builds Android mantêm a flag `io.flutter.embedding.android.EnableImpeller` como `false` por legacy.

Impeller renderiza blur e gradientes de forma mais eficiente que o Skia no Android em ARM GPUs (Adreno). Verificar se está ativo.

### Solução recomendada

1. Verificar no `AndroidManifest.xml` se há `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>` e remover se presente.
2. Testar no Xiaomi Pad 6 com `flutter run --profile` e comparar FPS antes/depois.

### Critério de aceite

- Nenhuma flag desabilitando Impeller no manifest
- FPS no profiler com Impeller ≥ FPS com Skia para o fluxo de troca de abas

---

## Métricas de Sucesso

| Métrica | Antes (estimado) | Meta |
|---------|-----------------|------|
| GPU time por frame (troca de aba) | ~40–60ms | < 12ms |
| FPS durante animação de bottom bar | ~15 FPS | ≥ 50 FPS |
| Número de `AnimationController` ativos | ~35 | ≤ 5 |
| `MaskFilter.blur` por frame | 6+ | 0 |
| Rebuild de tela completa ao trocar aba | Sim | Não (após #B2) |

---

## Estratégia de Implementação com Subagentes

Os itens foram agrupados por **independência de contexto** para execução paralela:

### Grupo 1 — Rendering / Painter (pode rodar em paralelo)
- **Subagente 1A:** `#A1` + `#C1` → `light_beam.dart` (remover blur, adicionar RepaintBoundary)
- **Subagente 1B:** `#A2` → `plpcg_bottom_nav_bar.dart` (RepaintBoundary nos itens)

### Grupo 2 — Bottom Nav Animations (sequencial: aguardar Grupo 1)
- **Subagente 2A:** `#A3` + `#A4` + `#A5` → `plpcg_bottom_nav_bar.dart` (`AnimatedTheme` → `TweenAnimationBuilder`, duração, TextPainter cache)
- **Subagente 2B:** `#B3` → `plpcg_bottom_nav_bar.dart` (consolidar em único AnimationController — pode rodar junto com 2A se em worktrees separados)

### Grupo 3 — Features independentes (pode rodar em paralelo com Grupo 2)
- **Subagente 3A:** `#B1` → `golden_tagged_container.dart` (desativar glow repeat)
- **Subagente 3B:** `#C2` → `AndroidManifest.xml` (verificar Impeller)

### Grupo 4 — Arquitetural (requer Grupo 1+2 estável)
- **Subagente 4A:** `#B2` → `app_router.dart` + `shell_scaffold.dart` (StatefulShellRoute)

> **Observação para subagentes:** Verificar `docs/PERFORMANCE_BACKLOG.md` (v1) para os itens #1–#7 que continuam em aberto. Este backlog (v2) foca **exclusivamente** em animações e rendering. Os dois backlogs são independentes e podem ser trabalhados em paralelo.

---

## Verificação Após Correções

1. **Profiler físico:** `flutter run --profile` no Xiaomi Pad 6 → Performance overlay → confirmar GPU/UI thread < 16ms
2. **DevTools "Highlight Repaints":** verificar que a bottom bar não pisca completa a cada troca de aba
3. **Testes de widget:** `flutter test test/widget/features/app_shell/ test/widget/features/catalog/ test/widget/`
4. **Smoke test visual:** scroll na Home, troca de todas as 5 abas, abertura/fechamento do leitor, glow da busca

---

## Histórico

| Data | Ação |
|------|------|
| 2026-06-18 | v2 criado — foco em animações e hardware de médio porte (Xiaomi Pad 6) |
