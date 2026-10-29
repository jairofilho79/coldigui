# Contrato de reprodução em segundo plano (áudio Coldigom)

## Android / iOS

- Pacotes: `just_audio` + `just_audio_background` (+ `audio_service`).
- Controles da notificação / tela bloqueada / headset estão ativos.
- A sessão de áudio é **global**: página `/audio` e face de áudio da playlist compartilham o mesmo player.

## Web

- `JustAudioBackground.init` **não** roda (`kIsWeb`).
- `JustAudioPlugin` é registrado explicitamente em boot (`ensureAudioWebPlatformRegistered`) — cobre registrant sem `just_audio_web` (evita `MissingPluginException`).
- A reprodução continua enquanto a aba/navegador permitir (políticas de autoplay, suspensão em background, etc.).
- Controles de mídia do SO **não** são garantidos.
- A UI mostra avisos localizados para o usuário final não confundir com bug:
  - `audioWebBackgroundNotice` — web genérica (Safari aberto, desktop).
  - `audioWebIosPwaNotice` — iPhone/iPad com app instalado na Home Screen (PWA standalone).

### Fluxo web iOS (tap → playback)

1. **Preservar user gesture** — no sheet, `playAudioInSession` corre no tap (não no frame seguinte). Playlist Isar continua `unawaited`.
2. **CORS + play no tap** — `setWebCrossOrigin(anonymous)` e `HTMLAudioElement.play()` da URL escolhida no mesmo gesto. Não usar WAV + `stop()`: o `stop()` destrói o elemento desbloqueado e o índice vai a 0.
3. **Streaming HTTP** — `<audio src>` aponta para `https://plpcg.com/api/coldigom/assets/...` (CORS + CORP). Não usar `blob:` com `crossOrigin=anonymous` — o browser recusa o load.
4. **Media Session** — metadados + handlers OS; `navigator.audioSession.type = 'playback'` quando disponível; reclaim ao voltar do background via `visibilitychange`.

### Limitações honestas (PWA iOS)

- Background infinito **não** é suportado em PWA standalone no iOS — limitação de plataforma.
- Lock screen / AirPods: melhor esforço via Media Session; pode pausar ao bloquear tela na PWA instalada.

## Fora de escopo (v1)

- Download offline de áudio.
- ~~Persistência / edição de audio flags~~ — implementado (Isar + `/api/audio-flags`).
- Catálogo de áudio PLPCG (apenas Coldigom).
