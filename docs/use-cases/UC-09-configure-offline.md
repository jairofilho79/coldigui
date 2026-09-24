# UC-09 — Configurar modo offline (primeira vez)

| Campo | Valor |
|-------|-------|
| **ID** | UC-09 |
| **Feature** | `offline` |
| **Prioridade** | Alta |
| **Ator** | Usuário (com ou sem login) |

## Pré-condições

Rede disponível; espaço em disco; catálogo coldigom sincronizado (a linha de estado do `/offline` diz quantos louvores e quando).

## Fluxo principal

1. Acessa `/offline` — uma secção, «Baixar para usar offline».
2. Marca os tipos de material a baixar. Sem login aparece a lista «Tipos» inteira; com login os tipos favoritos vêm primeiro e pré-marcados, e os outros ficam em «Outros tipos».
3. Toca «Baixar selecionados (~X MB)» → PDFs, áudios, cifras e gestos desses tipos ficam no aparelho (`DownloadColdigomMaterials`), com progresso por tipo e «Parar».

## Fluxos alternativos

- «Parar»: o que já baixou fica; «Tentar de novo» retoma saltando o que existe.
- «Atualizar»: sincroniza o catálogo e reconcilia o índice com o disco (banner «N removidos», só com «Dispensar»).
- «Remover todos os baixados»: apaga todos os PDFs e áudios do índice (cifras e gestos ficam).

## Pós-condições

Materiais dos tipos escolhidos disponíveis offline; catálogo coldigom local (`ColdigomPraiseCache`) com metadados, lista de materiais e letra.

## Regras de negócio

PDF → `OfflinePdfIndex` persistente; áudio → `OfflineAudioIndex` + `AudioStoragePort`; cifra/gestos → caches Isar. Seleção local em prefs `offlineColdigomKindIds`; idempotente sem checkpoint; estimativas por tipo quando o dump não traz `size`. Um estado de ocupado só: o `offlineMaintenanceLockProvider` (reconcile, download/remoção, normalização de ids legados). Sem `OFFLINE_AVAILABLE` nem seleção por categoria PLPCG (saíram em 23/09/2026).

## Componentes Flutter alvo

`OfflineSettingsScreen`, `ColdigomOfflineSection`, `DownloadColdigomMaterials`, `RemoveColdigomDownloads`, `offlineColdigomDownloadProvider`, `offlineCacheStatusProvider`

## Dependências

UC-10, UC-04

## Use case Dart

`lib/features/offline/domain/usecases/` — ver FEATURE_INDEX.md
