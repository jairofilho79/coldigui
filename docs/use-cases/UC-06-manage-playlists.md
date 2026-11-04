# UC-06 — Gerenciar playlists salvas

| Campo | Valor |
|-------|-------|
| **ID** | UC-06 |
| **Feature** | `playlists` |
| **Prioridade** | Média |
| **Ator** | Usuário |

## Pré-condições

Carousel ou playlist existente

## Fluxo principal

Criar, renomear, favoritar, excluir, remover PDF, carregar no carousel, abrir 1º no leitor.

## Fluxos alternativos

Nome default: lista dd/mm/yyyy HH:mm:ss

## Pós-condições

Playlist persistida em Isar

## Regras de negócio

Modelo: id, nome, entries[] (id e tipo do material), createdAt, favorita.
`pdfIds` e `audioIds` são projeções das entradas legíveis e de áudio.

### Materiais extraídos na playlist

- O seletor de materiais permite adicionar e remover PDFs, cifras extraídas,
  gestos extraídos, letras e áudios. YouTube continua sendo aberto externamente.
- Quando já existe um material do mesmo praise na lista ativa, as alternativas
  exibem "Trocar material" em vez de `+`. A troca substitui a primeira ocorrência
  desse praise na mesma posição, sem acrescentar outra entrada nem reordenar
  os demais louvores. O material já selecionado mantém a ação de remover.
- Após uma adição ou troca, as ações são atualizadas com o seletor aberto.
  Abas com um único material adicionável também expõem a troca quando o
  praise já está na lista.
- A letra aparece entre os materiais selecionáveis, sem substituir a prévia
  dedicada no cabeçalho do louvor.
- Abas de extraídos com um único material mostram a linha e o botão de
  adicionar. No seletor de troca, sem edição, o toque continua abrindo
  diretamente o material único e substituindo a ocorrência na playlist.
- Cada entrada preserva seu tipo e identificador ao salvar e restaurar a
  playlist. Letras usam `lyrics:<praiseId>` e abrem no leitor de letras.

- Abrir uma cifra ou gestos não adiciona o material à playlist nem regrava a
  lista existente. A adição é uma ação explícita pelo botão `+`.
- Quando o material aberto não pertence à lista ativa, o modal o mostra em uma
  seção separada e mantém o destaque no item focado da lista.

## Componentes Flutter alvo

PlaylistsScreen, CreatePlaylistFromCarousel

## Dependências

UC-05, UC-07

## Use case Dart

`lib/features/playlists/domain/usecases/` — ver FEATURE_INDEX.md
