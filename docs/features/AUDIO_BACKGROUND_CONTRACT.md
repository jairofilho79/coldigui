# Contrato de reprodução em segundo plano (áudio Coldigom)

## Android / iOS

- Pacotes: `just_audio` + `just_audio_background` (+ `audio_service`).
- Controles da notificação / tela bloqueada / headset estão ativos.
- A sessão de áudio é **global**: página `/audio` e face de áudio da playlist compartilham o mesmo player.

## Web

- `JustAudioBackground.init` **não** roda (`kIsWeb`).
- A reprodução continua enquanto a aba/navegador permitir (políticas de autoplay, suspensão em background, etc.).
- Controles de mídia do SO **não** são garantidos.
- A UI mostra o aviso localizado `audioWebBackgroundNotice` para o usuário final não confundir com bug.

## Fora de escopo (v1)

- Download offline de áudio.
- Persistência / edição de audio flags (apenas placeholder visual).
- Catálogo de áudio PLPCG (apenas Coldigom).
