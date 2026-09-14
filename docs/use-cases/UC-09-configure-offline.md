# UC-09 — Configurar modo offline (primeira vez)

| Campo | Valor |
|-------|-------|
| **ID** | UC-09 |
| **Feature** | `offline` |
| **Prioridade** | Alta |
| **Ator** | Usuário |

## Pré-condições

Rede disponível; espaço em disco

## Fluxo principal

1. Acessa offline. 2. Seleciona categorias. 3. Baixa ZIP. 4. Extrai PDFs. 5. OFFLINE_AVAILABLE=TRUE. 6. Coldigom (logado): no /offline marca kinds (favoritos pré-marcados + «Outros tipos») → «Baixar selecionados (~X MB)» → PDFs/áudios/cifras/gestos desses kinds ficam no aparelho (DownloadColdigomMaterials).

## Fluxos alternativos

Fases: fetching → extracting → storing → syncing

## Pós-condições

PDFs disponíveis offline; Catálogo Coldigom local (ColdigomPraiseCache) sincronizado por ETag no boot com rede — metadados, lista de materiais e letra disponíveis offline; materiais binários Coldigom são o plano 2.

## Regras de negócio

Filesystem + índice Isar OfflinePdfIndex

Coldigom por tipo (C1/O7): PDF → OfflinePdfIndex persistente; áudio → OfflineAudioIndex + AudioStoragePort (documents/plpcg_audio, Cache API plpcg-audio-store-v1); cifra/gestos → caches Isar existentes. Só logado (O9); seleção local em prefs offlineColdigomKindIds (O11); idempotente sem checkpoint (O12); estimativas por tipo quando o dump não traz size (O13).

## Componentes Flutter alvo

DownloadOfflinePackages, ExtractAndStorePdfs, DownloadColdigomMaterials, RemoveColdigomDownloads, ColdigomOfflineSection, offlineColdigomDownloadProvider

## Dependências

UC-10, UC-04

## Use case Dart

`lib/features/offline/domain/usecases/` — ver FEATURE_INDEX.md
