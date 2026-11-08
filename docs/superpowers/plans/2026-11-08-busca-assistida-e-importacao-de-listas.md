# Busca assistida e importacao de listas de louvores

**Data:** 2026-11-08

**Estado:** planejamento; funcionalidades ainda nao implementadas por esta entrega.

**Produto:** PLPCG, aplicativo coldigui.

**Projetos envolvidos:** coldigui, catalogo/API do coldigom e, somente quando necessario, Worker plpcg-catalog.

**Entrega desta sessao:** este documento e sua referencia no README. O incremento de versao exigido pelo fluxo de entrega nao significa que as funcionalidades abaixo foram implementadas.

## 1. Objetivo e requisitos confirmados

Facilitar a busca de um louvor e a montagem de uma lista a partir de informacoes
imperfeitas: erros de ortografia, numero incerto, nome incompleto, trecho da
letra, mensagem colada, fala ou foto.

- Fase 1: melhorar a precisao sem depender de IA generativa, embeddings ou BYOK.
- Oferecer um botao de microfone do proprio app, nao o microfone do teclado.
- Permitir tirar uma foto no app ou selecionar uma foto da galeria.
- Permitir compartilhar texto ou imagem de outro app para o PLPCG.
- Ao receber a entrada, iniciar sua analise para buscar a pagina de um louvor
  ou preparar uma lista, sem obrigar o usuario a copiar novamente o conteudo.
- Priorizar usuarios em geral e uma experiencia sem configuracao de chaves.
- Funcionamento offline e desejavel; recursos online sao aceitaveis.
- Preservar espaco para embeddings e transcricao mais avancada em outras sessoes.

Cada fase precisa de aprovacao propria para implementacao. Aprovar este
planejamento nao autoriza implementar todas as fases, contratar servicos,
fazer merge ou executar deploy.

## 2. Contexto existente e pontos de reutilizacao

Evidencias de leitura do codigo em 2026-11-08; revalidar antes de implementar.

| Superficie existente | Evidencia | Implicacao |
|---|---|---|
| Normalizacao de acentos, separadores e busca por prefixos | [LouvorSearchTokens](../../../lib/core/utils/louvor_search_tokens.dart) | Evoluir o mecanismo atual; nao substituir os acertos existentes por busca aproximada indiscriminada. |
| Ranking local por numero, titulo exato e parcial | [ColdigomSearchIndex](../../../lib/features/coldigom/domain/search/coldigom_search_index.dart) | Preservar identificadores, agrupamentos e correspondencias exatas. |
| Busca local com validacao remota e funcionamento offline | [HomeSearchProvider](../../../lib/features/catalog/presentation/providers/home_search_provider.dart) | Reutilizar fonte do catalogo, cancelamento e tratamento de atualizacao. |
| Letra no cache, mas fora dos tokens locais de busca | [ColdigomPraiseCacheMapper](../../../lib/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart) | Criar indice textual de letra separado, com ordem e posicao das palavras. |
| Importacao em lote que preserva repeticoes | [ActivePlaylistEditor](../../../lib/features/playlists/presentation/providers/active_playlist_editor.dart) | Reutilizar persistencia; adaptar resultado de erro e garantias de lote se necessario. |
| Escolha do material pelas preferencias do usuario | [preferredEntryForPraise](../../../lib/features/playlists/presentation/utils/preferred_entry_for_praise.dart) | Resolver primeiro o louvor; depois escolher material pela regra existente. |
| Criacao e atualizacao de playlists tipadas | [PlaylistRepository](../../../lib/features/playlists/domain/repositories/playlist_repository.dart) | Nao inventar outro armazenamento ou formato de lista. |
| Recebimento de links de louvores, listas e salas ao vivo | [DeepLinkListener](../../../lib/features/app_shell/presentation/widgets/deep_link_listener.dart) | Links existentes nao equivalem a recebimento de arquivos/texto pelo sistema operacional. |
| Pagina de louvor e rotas dos leitores | [RoutePaths](../../../lib/core/routing/route_paths.dart) | Identificacao de um louvor deve encaminhar para a pagina existente, sem abrir material arbitrario. |

No coldigom, `api/src/praiseQuery.ts` e `api/src/plpcgPraises.ts` ja contemplam
busca textual remota e trechos de letra. O comportamento por frase e a ordem
das palavras precisam ser preservados; nao regredir para palavras comuns
dispersas em toda a letra.

O coldigom tambem possui os scripts `scripts/indexar_acervo_completo.py` e
`scripts/buscar_louvores_semantico.py`, com referencia ao modelo Ollama
`embeddinggemma-2:latest`, e o arquivo `data/embeddings/acervo_embeddings.sqlite`.
A existencia desses arquivos nao comprova qualidade, compatibilidade mobile,
atualizacao do indice ou publicacao de busca semantica na API.

Este documento complementa o planejamento anterior de
[trechos de letra nos resultados](../specs/2026-09-15-trecho-letra-pesquisa-design.md);
nao altera retrospectivamente suas decisoes.

## 3. Arquitetura proposta e invariantes

```text
Texto digitado/colado ---------------------+
Microfone -> transcricao ------------------+
Camera/galeria -> reconhecimento de texto -+-> entrada original + texto revisavel
Compartilhamento -> texto ou imagem -------+       |
                                                  v
                                  interpretar pistas e itens
                                                  |
                                                  v
                                resolver candidatos do catalogo
                                                  |
                             +--------------------+--------------------+
                             v                                         v
                   buscar um louvor                         revisar uma lista
                             |                                         |
                      pagina existente                      confirmacao explicita
                                                                       |
                                                            persistencia existente
```

### 3.1 Decisoes de base

- Separar reconhecimento, interpretacao, correspondencia e persistencia.
- Um resolvedor de dominio compartilhado para todas as entradas. A apresentacao
  e os controles diferem entre busca e importacao, nao as regras de identidade.
- Correspondencias exatas continuam prioritarias. Fuzzy search sugere
  candidatos, nao altera titulo, numero ou letra oficiais.
- Usar titulo, aliases, numero/coletanea e trechos de letra como evidencias
  separadas. Numero e nome conflitantes devem ser mostrados, nao ocultados.
- Similaridade textual ou futura similaridade vetorial nao e probabilidade de
  acerto. Nao apresentar percentuais de confianca sem calibracao validada.
- Resolver para `praiseId`/`shortId` existentes; converter para `PlaylistEntry`
  com material e tipo somente depois, respeitando as preferencias atuais.
- Manter consulta simples funcionando sem usar o importador de mensagens.
- Nao aplicar filtros ocultos da Home como exclusoes de uma lista importada.
  Filtros do importador, se houver, precisam ser visiveis e deliberados.

### 3.2 Estados observaveis

Cada item da entrada conserva texto original, ordem, pistas extraidas,
candidatos, motivo da correspondencia e escolha confirmada.

| Estado | Comportamento |
|---|---|
| Resolvido | Correspondencia clara; mostrar o registro antes da confirmacao da lista. |
| Precisa de escolha | Mostrar candidatos plausiveis, sem escolher silenciosamente. |
| Informacoes conflitantes | Expor a divergencia entre numero, titulo ou trecho. |
| Nao encontrado | Permitir editar ou remover explicitamente; nao inventar um louvor. |
| Louvor identificado sem material adicionavel | Permitir abrir sua pagina e informar a impossibilidade de inclui-lo na lista; nao descartar silenciosamente nem inventar material. |
| Catalogo indisponivel ou incompleto | Informar a limitacao e oferecer nova tentativa; nao confundir com inexistencia do louvor. |
| Falha de reconhecimento/rede/armazenamento | Mostrar erro e preservar a revisao para recuperacao, conforme viabilidade e consentimento. |

### 3.3 Busca de pagina versus montagem de lista

- Uma entrada com um louvor claramente identificado pode encaminhar para
  `/louvor/:id`, desde que essa seja a acao escolhida ou claramente apresentada.
- Varios itens identificados levam a previsualizacao da lista.
- Quantidade de candidatos de uma busca nao determina quantidade de itens:
  um unico nome ambiguo continua sendo um item com varias opcoes.
- Permitir alternar entre "Buscar louvor" e "Criar lista". Um unico louvor
  tambem pode compor uma lista, sem uma inferencia impedir essa escolha.
- Receber/interpretar a entrada nao autoriza salvar, publicar, sincronizar uma
  nova lista ou sobrescrever a lista ativa sem confirmacao.
- Links PLPCG reconhecidos continuam usando seu fluxo existente de navegacao ou
  importacao, sem serem reinterpretados como titulos por aproximacao.

## 4. Fases e dependencias

| Fase | Resultado para o usuario | Prerequisitos reais |
|---|---|---|
| 1 | Busca tolerante e lista revisavel a partir de texto | Catalogo, preferencias e persistencia atuais; aliases dependem de contrato e dados do coldigom. |
| 2 | Botao proprio de microfone para busca e listas | Resolvedor e revisao da fase 1; estudo de transcricao por plataforma. |
| 3 | Foto pela camera ou galeria para busca e listas | Resolvedor e revisao da fase 1; estudo de reconhecimento de imagem. |
| 4 | Compartilhar texto/imagem para o PLPCG | Texto depende da fase 1; imagens tambem da fase 3; nao depende do microfone. |
| 5 | Busca semantica e transcricao mais avancada, opcionais | Para embeddings: base textual e contrato vetorial; para transcricao: fluxo da fase 2. |

Fases 2 e 3 podem ser investigadas em paralelo depois da base textual.
O recebimento de texto da fase 4 pode ser antecipado depois da fase 1.
Numero da fase expressa prioridade de produto, nao uma dependencia artificial
de todas as fases anteriores.

As tarefas abaixo sao incrementos propostos, nao trabalho executado. Antes de
cada incremento, confirmar arquivos e dividir novamente se o escopo ultrapassar
uma sessao focada. Os caminhos existentes acima sao pontos de investigacao,
nao uma lista fechada de arquivos obrigatoriamente alterados.

## 5. Fase 1 - Busca precisa e listas a partir de texto

**Objetivo:** reconhecer informacao imperfeita sem LLM, embeddings ou chaves.
**Fora desta fase:** reconhecimento de audio/imagem, agente conversacional,
recomendacao tematica por embeddings e alteracao automatica do catalogo.

### 1.1 Fixar exemplos, baseline e criterios de liberacao

- [ ] Reunir consultas e mensagens reais autorizadas, com identificadores
  esperados, ambiguidades e casos sem resposta; usar exemplos sinteticos nos
  testes versionados quando houver dados pessoais ou direitos de terceiros.
- [ ] Separar exemplos de ajuste dos exemplos de avaliacao; medir a busca atual.
- [ ] Definir antes da implementacao os limiares de qualidade, latencia e
  memoria por dispositivo; nao inventar valores como se ja estivessem medidos.
- **Aceite:** corpus rotulado e protocolo reprodutivel de avaliacao.
- **Verificacao:** medir acerto do primeiro candidato, presenca nos candidatos,
  escolhas indevidas, abstencao, tempo e correcoes ate salvar.
- **Dependencias:** nenhuma. **Superficie:** fixtures e testes de busca.

### 1.2 Acrescentar tolerancia ortografica

- [ ] Comparar Damerau-Levenshtein e fragmentos de caracteres para gerar
  candidatos com letras faltantes, repetidas, substituidas ou transpostas.
- [ ] Limitar aproximacao conforme tamanho e evidencias; palavras curtas e
  numeros nao recebem a mesma tolerancia de titulos longos.
- [ ] Preservar prioridade dos acertos exatos, prefixos, acentos e separadores.
- **Aceite:** erros rotulados recuperam candidatos corretos sem empurrar um
  candidato aproximado acima de uma correspondencia exata forte.
- **Verificacao:** testes unitarios de positivos, negativos e regressao; medir
  custo sobre o catalogo real sem recalcular indices a cada tecla.
- **Dependencias:** 1.1. **Superficie:** utilitarios e indice local de busca.

### 1.3a Publicar nomes alternativos pelo coldigom

- [ ] Definir contrato aditivo de aliases ligados ao louvor, com validacao de
  colisoes e possibilidade de varios louvores compartilharem um alias ambiguo.
- [ ] Curar nomes populares e abreviacoes. Registrar coletanea/edicao para
  numeracoes alternativas somente se esses dados forem confiaveis.
- [ ] Preservar consumidores antigos e o mecanismo de atualizacao do catalogo.
- **Aceite:** aliases rastreaveis chegam ao catalogo sem substituir nomes oficiais.
- **Verificacao:** testes de API/dump, aliases ambiguos e compatibilidade.
- **Dependencias:** 1.1. **Superficie:** schema/contrato e catalogo do coldigom;
  dividir migracao e publicacao em entregas distintas se necessario.

### 1.3b Consumir aliases no coldigui

- [ ] Mapear e indexar aliases separados do titulo oficial, com cache offline.
- [ ] Suportar ausencia do campo em catalogos antigos e atualizacao de aliases.
- **Aceite:** alias exato recupera o louvor; colisoes permanecem alternativas.
- **Verificacao:** testes de DTO/cache/indice com dados antigos e novos.
- **Dependencias:** 1.3a. **Superficie:** mapeamento, cache e indice do coldigui.

### 1.4 Buscar trechos de letra localmente

- [ ] Indexar letras disponiveis separadamente, conservando posicao e ordem.
- [ ] Priorizar frase exata e palavras proximas; permitir pequenas diferencas
  sem aceitar como evidencias fortes palavras comuns dispersas.
- [ ] Exibir trecho e motivo do resultado; diferenciar letra ausente no cache
  de consulta sem correspondencia e usar busca remota quando disponivel.
- **Aceite:** trecho rotulado encontra o louvor online/offline conforme dados
  disponiveis, preservando busca por numero/titulo e agrupamentos.
- **Verificacao:** testes de frases, acentos, pontuacao, erros, repeticoes de
  palavras, negativos e atualizacao do indice; medir memoria e latencia.
- **Dependencias:** 1.1; usar a tolerancia de 1.2 quando estiver validada.
- **Superficie:** cache/indice de letra e apresentacao dos resultados.

### 1.5 Cruzar pistas em um resolvedor comum

- [ ] Interpretar numero, nome/alias e trecho como pistas independentes,
  usando os candidatos de 1.2, 1.3b e 1.4 conforme disponibilidade.
- [ ] Distinguir numero de coletanea de posicao da lista; numero isolado
  incerto nao autoriza escolher por proximidade numerica.
- [ ] Classificar resolucao, ambiguidade, conflito e ausencia de evidencias.
- **Aceite:** numero e nome divergentes ficam visiveis; um nome ambiguo nao
  gera varios itens; resultado nao contem identificadores inventados.
- **Verificacao:** testes de ranking, concorrentes proximos, conflitos e
  abstencao com corpus de 1.1.
- **Dependencias:** 1.2 e 1.4; integrar aliases apos 1.3b.
- **Superficie:** resolvedor de dominio e suas entidades/testes.

### 1.6 Integrar o resolvedor na busca existente

- [ ] Integrar Home e Biblioteca preservando filtros, preferencias e
  agrupamentos; sugestoes aproximadas devem explicar sua origem.
- [ ] Manter cancelamento de consulta, offline, navegacao e aviso de falha.
- **Aceite:** buscar e selecionar um candidato abre a pagina correta sem
  adicionar automaticamente o louvor a uma lista.
- **Verificacao:** testes de providers/widgets e busca real nas plataformas.
- **Dependencias:** 1.5. **Superficie:** providers e resultados Home/Biblioteca;
  separar essas duas integracoes se excederem uma entrega pequena.

### 1.7 Interpretar texto e revisar a lista proposta

- [ ] Oferecer entrada por texto colado e preparar itens com ordem original.
  Distinguir cabecalhos, numeracao, comentarios e trechos em varias linhas;
  nao dividir cegamente toda virgula, quebra de linha ou conjuncao.
- [ ] Exibir original, correspondencia e alternativas; permitir corrigir,
  reordenar, remover explicitamente e manter repeticoes intencionais.
- [ ] Oferecer "Buscar louvor" ou "Criar lista", sem apagar linhas ambiguas
  silenciosamente como se fossem comentarios.
- **Aceite:** revisao inclui todos os itens reconhecidos e pendencias; nenhum
  registro e gravado enquanto o usuario apenas edita a proposta.
- **Verificacao:** testes do interpretador e widgets para mensagens simples,
  mistas, vazias, um item ambiguo e varios itens.
- **Dependencias:** 1.5. **Superficie:** interpretador e tela de revisao;
  implementar logica e apresentacao em incrementos separados.

### 1.8 Confirmar e persistir pelo fluxo existente

- [ ] Oferecer criar nova lista ou acrescentar a atual, com nome e resumo.
- [ ] Aplicar material preferido, tipos e ordem; nao exigir login para a
  capacidade local quando os fluxos atuais nao o exigirem. Itens identificados
  sem material adicionavel exigem resolucao ou exclusao explicita antes de salvar.
- [ ] Garantir confirmacao unica, evitar lote parcial duplicado em nova
  tentativa e informar falha de armazenamento sem resultado de sucesso.
- **Aceite:** cancelamento nao altera listas; confirmacao grava o conteudo
  revisado, sem sobrescrever a lista ativa ou editar sessao ao vivo seguida.
- **Verificacao:** testes de persistencia, duplo toque, erro/retry, repeticoes,
  preferencias, troca de lista durante revisao e modo ao vivo.
- **Dependencias:** 1.7. **Superficie:** use cases/editor e confirmacao.

### Checkpoint da fase 1

- [ ] Corpus de avaliacao atende aos limiares previamente acordados.
- [ ] Casos exatos atuais nao regridem; falsos positivos e ambiguidades sao visiveis.
- [ ] Busca e importacao usam o mesmo resolvedor; listas mantem ordem e materiais.
- [ ] Nenhum download de modelo ou configuracao BYOK e necessario.
- [ ] Usuario valida a experiencia antes da implementacao das entradas seguintes.

## 6. Fase 2 - Pesquisa e criacao de lista por voz

**Objetivo:** botao de microfone visivel no proprio app, em busca e importacao.
**Dependencia:** fase 1, especialmente 1.5-1.8.

### 2.1 Validar o reconhecedor de fala por plataforma

- [ ] Comparar reconhecimento nativo e ASR dedicado adequado ao portugues,
  usando titulos, numeros, pausas e listas faladas do corpus autorizado.
- [ ] Verificar idioma, disponibilidade offline, duracao suportada, destino
  do audio e custo. O modo local precisa ser comprovado, nao presumido.
- **Aceite:** escolha tecnica e limites documentados para Android, iOS e web;
  formatos de transcricao preservam original e resultados finais/parciais.
- **Verificacao:** prototipo em aparelhos fisicos e navegador suportado.
- **Dependencias:** 1.1. **Superficie:** adaptador de fala/prototipo; nao mudar
  o resolvedor para acomodar um provedor especifico.

### 2.2 Capturar fala pelo botao do app

- [ ] Criar controles acessiveis de iniciar, parar e cancelar, com indicador
  claro de escuta e permissao solicitada somente quando necessaria.
- [ ] Tratar interrupcao, silencio, permissao negada e ausencia de suporte;
  liberar microfone e recursos ao sair ou cancelar.
- **Aceite:** usuario inicia e encerra a captura sem abrir teclado ou usar
  seu microfone; transcricao revisavel aparece no contexto escolhido.
- **Verificacao:** widgets com adaptador falso e testes manuais reais por plataforma.
- **Dependencias:** 2.1. **Superficie:** adaptador/permissoes e controles de voz.

### 2.3 Resolver a fala e encaminhar a acao

- [ ] Reutilizar o interpretador e o resolvedor para fala de um ou varios
  louvores; converter numeros falados somente com regras verificadas.
- [ ] Permitir editar a transcricao e escolher entre busca de pagina e lista.
- **Aceite:** um candidato confirmado abre o louvor correto; varios itens
  produzem revisao e so persistem apos confirmacao, sem reescrever nomes oficiais.
- **Verificacao:** fluxo completo com erros de transcricao, pausas, ordem e
  numeros incorretos; avaliar louvores identificados, nao so palavras transcritas.
- **Dependencias:** 2.2 e 1.5-1.8. **Superficie:** integracao de voz com busca/revisao.

### Checkpoint da fase 2

- [ ] Botao proprio validado; estados de escuta e erro sao claros.
- [ ] Audio nao e enviado remotamente sem consentimento informado.
- [ ] Limites de fala continua e offline sao declarados sem promessa indevida.
- [ ] Texto digitado/colado continua funcionando independentemente da voz.

## 7. Fase 3 - Camera e galeria

**Objetivo:** usar foto capturada ou selecionada para encontrar louvores/listas.
**Dependencia:** fase 1; nao depende da fase 2.

### 3.1 Comparar reconhecimento em imagens reais

- [ ] Separar screenshots, impressos, manuscritos em letra de forma e cursiva.
- [ ] Comparar OCR local de plataforma com servico especializado ou
  multimodal somente quando os resultados justificarem processamento remoto.
- [ ] Medir identificacao final dos louvores, ordem dos itens e correcoes;
  verificar formatos, resolucao, rotacao, tamanho maximo e custo.
- **Aceite:** tecnologia e limites escolhidos com evidencia por classe de imagem,
  sem confundir suporte a texto impresso com precisao comprovada em manuscrito.
- **Verificacao:** corpus de imagens autorizado e aparelhos representativos.
- **Dependencias:** 1.1. **Superficie:** prototipo/adaptador de reconhecimento.

### 3.2 Capturar ou selecionar uma foto

- [ ] Oferecer "Tirar foto" e "Escolher da galeria", com preview, troca da
  imagem e recorte/rotacao quando o estudo demonstrar necessidade.
- [ ] Usar seletores/permissoes minimas adequadas; tratar cancelamento,
  formato invalido, imagem grande e recurso indisponivel.
- **Aceite:** ambas as entradas chegam ao mesmo fluxo; web usa camera quando
  suportada e permissao concedida, com selecao de arquivo como alternativa clara.
- **Verificacao:** dispositivos fisicos e navegador, inclusive fotos rotacionadas
  e formatos usuais de Android/iOS; limites definidos antes de implementar.
- **Dependencias:** 3.1. **Superficie:** adaptadores de camera/galeria e preview.

### 3.3 Revisar reconhecimento e resolver

- [ ] Conservar imagem/orientacao de leitura e texto revisavel; respeitar
  colunas e ordem em vez de apenas concatenar palavras detectadas.
- [ ] Mostrar trechos ilegveis/ambiguos e oferecer corrigir, refazer foto
  ou reconhecimento remoto consentido, se essa opcao for aprovada.
- **Aceite:** foto de um louvor pode levar a sua pagina; repertorio leva a
  revisao da lista, sem excluir itens silenciosamente nem salvar sozinho.
- **Verificacao:** fluxo completo com falhas de OCR, duplicatas, numeros,
  colunas, modo offline e cancelamento.
- **Dependencias:** 3.2 e 1.5-1.8. **Superficie:** integracao imagem/texto/revisao.

### Checkpoint da fase 3

- [ ] Camera e galeria funcionam nas plataformas acordadas.
- [ ] Manuscritos atendem ao criterio acordado ou a limitacao e declarada.
- [ ] Falha local nao provoca upload remoto silencioso.
- [ ] Temporarios sao removidos conforme politica de retencao, sem acessar
  novamente toda a galeria ou conservar imagem sem necessidade.

## 8. Fase 4 - Compartilhar para o PLPCG

**Objetivo:** escolher PLPCG no compartilhamento de outro app e receber texto
ou imagem, iniciando o fluxo adequado sem nova copia manual.
**Dependencias:** fase 1 para texto; fase 3 para reconhecimento das imagens.

### 4.1 Definir recepcao, fila e encaminhamento

- [ ] Criar entrada compartilhada desacoplada da plataforma, com identidade
  de evento, conteudo validado e fila limitada ate catalogo/UI estarem prontos.
- [ ] Definir tipos e limites aceitos, vida dos arquivos temporarios,
  confirmacao de consumo e tratamento de eventos simultaneos/duplicados.
- [ ] Usar links conhecidos antes de interpretacao textual; encaminhar texto
  ao fluxo da fase 1 e imagem ao da fase 3.
- **Aceite:** o mesmo evento nao gera processamento/persistencia duplicados;
  dois compartilhamentos intencionais iguais continuam sendo eventos distintos.
- **Verificacao:** testes de fila, cold start, retomada, cancelamento, storage
  indisponivel e catalogo ainda hidratando.
- **Dependencias:** 1.5-1.8; imagens completas apos 3.3.
- **Superficie:** recepcao compartilhada, lifecycle e roteamento.

### 4.2 Receber no Android

- [ ] Registrar somente os MIME types realmente suportados; avaliar
  `ACTION_SEND` e `ACTION_SEND_MULTIPLE` conforme limite de anexos aprovado.
- [ ] Ler `EXTRA_TEXT` e URIs de anexos com permissoes corretas; copiar
  temporarios quando necessario antes da permissao expirar.
- **Aceite:** PLPCG aparece para texto/imagem e processa ao abrir ou retomar,
  sem regredir deep links de louvor, playlist e Lista ao Vivo.
- **Verificacao:** aparelho fisico com compartilhamento de mensagem, galeria
  e screenshot, app fechado/aberto/em segundo plano e novo intent.
- **Dependencias:** 4.1; 3.3 para imagens.
- **Superficie:** manifest, entrada Android e ponte para Flutter.

### 4.3 Receber no iOS/iPadOS

- [ ] Validar uma Share Extension e troca de conteudo por App Group usando
  APIs permitidas, identificadores e assinatura apropriados.
- [ ] Manter a extensao leve; validar limites de memoria/tempo e handoff
  antes de prometer OCR completo ou abertura automatica do app principal.
- [ ] Se o sistema nao permitir o handoff desejado, definir e aprovar UX de
  conteudo pendente e abertura explicita do PLPCG, sem hacks de lancamento.
- **Aceite:** PLPCG recebe texto/imagem na folha de compartilhamento e o
  conteudo chega ao fluxo aprovado sem perda, nova copia manual ou duplicacao.
- **Verificacao:** iPhone/iPad fisicos, extensao encerrada/interrompida,
  app fechado/aberto, retomada e pacote assinado com a extensao.
- **Dependencias:** 4.1; 3.3 para imagens; aprovacao do handoff apos prototipo.
- **Superficie:** novo target de extensao, App Group, configuracao e recepcao Flutter.

### 4.4 Cobrir web sem prometer paridade inexistente

- [ ] Avaliar Web Share Target em PWA instalada e navegadores suportados,
  verificando manifest, recebimento de arquivos e hospedagem atual.
- [ ] Manter colar texto e upload de imagem nas plataformas sem share target;
  informar suporte em vez de mostrar uma acao que nao funciona.
- **Aceite:** matriz distingue share-in de share-out; suporte parcial nao
  compromete as entradas de texto/foto nem expoe conteudo em URL/logs.
- **Verificacao:** navegador real, PWA instalada/navegacao normal e, se houver
  recepcao POST de arquivos, limites e roteamento compativeis com a hospedagem.
- **Dependencias:** 4.1; 3.3 para imagens.
- **Superficie:** manifest web, recepcao e eventual service worker/hospedagem.

### Checkpoint da fase 4

- [ ] Texto e imagem sao recebidos nas plataformas nativas acordadas.
- [ ] Conteudo com um item e varios candidatos nao vira lista de candidatos.
- [ ] Resultado identifica a pagina ou prepara revisao; nao modifica lista sem confirmar.
- [ ] Cold start, background, duplicacao, permissao temporaria e limpeza foram testados.
- [ ] Handoff iOS e limitacoes web possuem evidencia e aprovacao explicitas.

## 9. Fase 5 - Evolucao opcional, em sessoes separadas

Esta fase nao bloqueia a entrega das anteriores e nao autoriza adotar um modelo
generativo para resolver lacunas que a busca textual pode corrigir.

### 5.1 Integrar embeddings para consultas sem correspondencia textual

- [ ] Validar modelo/revisao, variante, dimensoes, prefixos de tarefa,
  normalizacao, quantizacao, metrica e versao do catalogo dos vetores existentes.
- [ ] Comparar distribuicao de vetores com geracao local da consulta versus
  busca semantica remota. Dimensoes iguais nao garantem espaco vetorial igual.
- **Aceite:** recuperar trechos/descricoes do corpus sem degradar acertos exatos;
  tema semelhante continua sendo sugestao, nao identidade confirmada.
- **Verificacao:** corpus independente, memoria/download/latencia e compatibilidade
  entre vetores do coldigom e consultas do coldigui.
- **Dependencias:** fase 1 e estudo/contrato vetorial do coldigom.

### 5.2 Evoluir a transcricao de audio

- [ ] Comparar ASR mais robusto para fala longa, pausas, sotaques, vocabulario
  do catalogo e ruido; preservar transcricao original e revisao.
- [ ] Manter o adaptador da fase 2 e a separacao entre transcrever e executar
  uma acao; nao "embelezar" texto inventando nomes ou numeros.
- **Aceite:** melhoria medida na identificacao e no esforco de revisao, nao
  apenas texto mais fluente; captura/permissoes atuais nao regridem.
- **Verificacao:** corpus de audio autorizado e aparelhos reais.
- **Dependencias:** fase 2; nao depende de 5.1.

### 5.3 Avaliar IA generativa somente para lacunas comprovadas

- [ ] Comparar auxilio online gerenciado, BYOK avancado e modelo local
  opcional, sem transformar download grande/chave em requisito para todos.
- [ ] Justificar ganho frente a base deterministica, custo, privacidade,
  suporte de runtime Flutter e cobertura dos aparelhos.
- **Aceite:** estudo documenta beneficio e limite; qualquer execucao continua
  restrita a identificadores do catalogo e confirmacao do usuario.
- **Verificacao:** experimento aprovado, corpus independente e comparacao
  com a mesma tarefa sem LLM; nao incluir segredos em app, sync ou logs.
- **Dependencias:** evidencia de lacuna e aprovacao separada de experimento.

## 10. Responsabilidades dos projetos

| Projeto | Responsabilidade proposta | Nao presumir |
|---|---|---|
| coldigui | Captura/recepcao, cache e indices locais, interpretador/resolvedor, revisao, pagina do louvor e persistencia pelos fluxos atuais. | Que um plugin resolva sozinho todas as plataformas ou que o cache esteja sempre completo. |
| coldigom | Catalogo canonico, aliases/coletaneas quando curados, letras e busca remota; exportacao/contrato de embeddings futuramente. | Que um SQLite de embeddings local ja seja uma API de producao. |
| plpcg-catalog | Preservar auth/playlists/sync atuais; ampliar apenas se processamento gerenciado exigir autenticao/limites nesse dominio. | Que importar texto local exija um novo backend ou um novo formato de playlist. |

Aliases e contratos de catalogo exigem entregas coordenadas nos dois repositorios.
Este documento no coldigui nao cria migracoes, commits ou PRs no coldigom.
Qualquer servico online futuro precisa de uma decisao explicita sobre onde
ficara, suas credenciais, limites, custo e responsabilidade operacional.

## 11. Qualidade, privacidade e recuperacao

- Conteudo recebido e entrada nao confiavel: validar tipo real, tamanho,
  quantidade, URIs, decodificacao e limites de processamento antes de usar.
- Nao ler conversas de WhatsApp, varrer galeria ou acessar microfone em background.
  Receber somente o conteudo que o usuario deliberadamente compartilhou/selecionou.
- Avisar antes de enviar audio, foto ou texto a terceiros; falha local nao e
  consentimento para upload. Definir retencao e exclusao antes de integrar servico.
- Nao registrar conteudo bruto, fotos, audio ou chaves em logs de diagnostico.
  Corpus real fica fora do Git salvo autorizacao adequada e ausencia de dados sensiveis.
- Retentativas precisam preservar revisao sem salvar duas vezes; cancelamento
  libera captura/temporarios e nao altera listas.
- Reaproveitar localizacao, acessibilidade, notificacoes de erro e preferencias
  do app; nao transformar falha em sucesso com zero itens adicionados.
- Nao incluir telemetria nova silenciosamente. Medicoes locais e corpus de
  teste sao suficientes para o primeiro baseline; coleta de produto exige decisao propria.

## 12. Validacao e checkpoints de entrega

### 12.1 Testes existentes a preservar

Executar seletores pertinentes na implementacao, acrescentando os testes novos
da tarefa no mesmo runner. Este planejamento nao executa testes de features.

```bash
flutter test \
  test/unit/core/utils/louvor_search_tokens_test.dart \
  test/unit/features/coldigom/coldigom_search_index_test.dart \
  test/unit/features/catalog/home_search_provider_test.dart \
  test/unit/features/playlists/import_shared_playlist_from_url_test.dart \
  test/unit/features/playlists/preferred_entry_for_praise_test.dart
```

Para widgets, incluir os seletores de Home/revisao modificados. Para coldigom,
usar Vitest/typecheck nos arquivos afetados, confirmando comandos naquele repo.
Para superficies web, testar em navegador real; para microfone/camera/share-in,
testar aparelhos fisicos e nao apenas mocks ou simuladores.

A verificacao completa do app segue o [README](../../../README.md):
`./scripts/test_all.sh` ou `./scripts/test_all.sh --vm-only` conforme o escopo.
Escalar para a suite completa quando a cobertura/regressao exigir, nao executar
builds de lojas a cada ajuste de logica.

### 12.2 Medidas de aceite a fixar em 1.1

| Medida | Evidencia exigida |
|---|---|
| Precisao de identidade | Proporcao de identificadores corretos e escolhas indevidas por classe de entrada. |
| Recuperacao de candidatos | Presenca do louvor esperado nas alternativas; tamanho util da lista de alternativas. |
| Tratamento de ambiguidade | Casos ambiguos/conflitantes nao recebem decisao automatica indevida. |
| Fidelidade da lista | Ordem, quantidade, repeticoes e materiais equivalem a revisao confirmada. |
| Esforco do usuario | Correcoes, toques e tempo ate encontrar a pagina ou salvar a lista. |
| Desempenho | Latencia p50/p95, memoria, download e consumo em aparelhos representativos. |
| Custo online | Custo por lista/imagem/minuto com retentativas, volume e limites declarados. |

Nao existe percentual de precisao ou latencia comprovado por este documento.
Limiares quantitativos e dispositivos-alvo precisam ser acordados antes dos
experimentos e verificados em corpus independente.

### 12.3 Entrega por incremento

- [ ] Apresentar entendimento e DoR/DoD; aguardar aprovacao do escopo.
- [ ] Registrar branch `feature/` ou `fix/` antes de alterar cada repositorio.
- [ ] Implementar um incremento com testes/validacao apropriados e revisar
  compatibilidade entre versoes quando houver alteracao de contrato.
- [ ] Preparar versao uma unica vez e criar PR restrito a tarefa no coldigui,
  conforme [task-delivery](../../../.github/skills/task-delivery/SKILL.md).
- [ ] Merge somente com aprovacao do PR e seu HEAD atual; deploy com outra
  autorizacao. Checklist ou PR de planejamento nao equivale a feature entregue.

## 13. Riscos e decisoes pendentes

| Risco/decisao | Mitigacao ou gate |
|---|---|
| Aproximacao sugere louvor errado com aparencia de certeza | Corpus negativo, prioridade exata, motivos visiveis e abstencao. |
| Numero errado domina um titulo correto | Avaliar pistas separadamente e expor conflito. |
| Aliases/numeracoes sem curadoria | Definir origem, colisao, coletanea/edicao e contrato antes de publicar. |
| Parsing confunde letra, comentario ou ordem com varios louvores | Conservar linhas/original, revisao e casos rotulados. |
| Cache sem letra/catalogo recente | Informar completude, sincronizar quando possivel e nao alegar inexistencia. |
| OCR de cursiva ou audio nao atende qualidade | Experimento antecipado; nao fixar provedor nem prometer precisao sem teste. |
| iOS nao permite abrir app como imaginado pelo compartilhamento | Prototipo de extensao/handoff e aprovacao da UX antes de implementar 4.3. |
| Web nao pode receber shares em todo navegador | Matriz de capacidade e alternativa por texto/upload. |
| Importacao parcial seguida de retry duplica itens | Garantias de persistencia e identificacao da confirmacao em 1.8. |
| Limites ainda indefinidos | Fixar duracao de audio, tamanho/quantidade de anexos, timeout e retencao nos estudos de cada fase. |

## 14. Fontes tecnicas e limites da pesquisa

Consultadas em 2026-11-08; revalidar API, versoes e suporte antes de implementar.

- [ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2):
  OCR de imagens em plataformas moveis.
- [Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images):
  reconhecimento de texto processado no dispositivo.
- [Cloud Vision: manuscritos](https://cloud.google.com/vision/docs/handwriting):
  alternativa online especializada, sujeita a custo e consentimento.
- [ML Kit Digital Ink](https://developers.google.com/ml-kit/vision/digital-ink-recognition):
  reconhece tracos desenhados na tela, nao fotografias de papel.
- [speech_to_text](https://pub.dev/packages/speech_to_text):
  adaptador Flutter comunitario voltado a comandos/frases curtas; nao confundir
  com uma solucao garantida de ditado longo.
- [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer):
  verificar servico/localidade e modo on-device; o reconhecimento comum pode
  transmitir audio remotamente.
- [Apple: supportsOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition):
  capacidade offline deve ser verificada.
- [Android: receber compartilhamentos](https://developer.android.com/training/sharing/receive):
  a pagina atual utiliza Compose; aplicar conceitos de intents/MIME/URIs pela
  integracao Flutter/nativa, sem copiar navegacao Compose para este projeto.
- [Apple: Share Extensions](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html):
  guia conceitual arquivado; validar APIs atuais, App Group e restricoes reais
  de extensao/handoff no prototipo iOS.
- [Web Share Target](https://developer.chrome.com/docs/capabilities/web-apis/web-share-target):
  depende de instalacao e suporte da PWA/navegador; nao e o mesmo que compartilhar para fora.
- [EmbeddingGemma 2](https://ai.google.dev/gemma/docs/embeddinggemma),
  [Gemma 4](https://ai.google.dev/gemma/docs/core) e
  [LiteRT-LM](https://developers.google.com/edge/litert-lm/overview):
  possibilidades futuras, sem comprovar compatibilidade dos vetores existentes
  ou desempenho no aparelho dos usuarios.

Nao foram executados benchmarks de busca, microfone, camera, OCR ou share-in
nesta entrega documental. Nenhum servico pago foi acionado, nenhum modelo foi
baixado e nenhuma alteracao foi feita nos outros projetos.
