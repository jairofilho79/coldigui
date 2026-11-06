# Leitor de partituras interativas

## Formatos e integracao

O catalogo identifica `mscz`, `mxl` e `musicxml` como `MaterialKind.score`.
Esses materiais abrem em `/partitura?pdfId=<id codificado>`, na mesma familia
de navegacao/carrossel usada por PDFs, cifras e gestos, mas em aba propria.
Quando o dump omite `r2`, o coldigui deriva a chave R2 de `praiseId`,
`materialId` e extensao. Uma nova versao logica do catalogo faz instalacoes
com cache antigo buscar o dump completo uma vez; depois o ETag volta ao fluxo
normal. A recuperacao nao exige apagar os dados locais.
O parser tambem aceita MSCX e MusicXML/XML descomprimidos pelo conteudo.

MSCZ e ZIP de MuseScore, nao MusicXML. A feature usa o leitor MSCX do
`crisp_notation_core`, com adaptacao para cifras do MuseScore 4.6 e ancoragem
de cifras sobre pausas. MXL usa `META-INF/container.xml`, com descoberta do
primeiro candidato quando nao ha uma raiz utilizavel. Letra, cifra e baixos
de cifras com barra fazem parte dos testes de regressao.

A leitura limita a entrada a 16 MiB, o XML a 4 MiB e o container a 64 KiB.
ZIPs aceitam ate 128 entradas, 8 MiB por entrada, 16 MiB expandidos e
razao maxima 200. Metadados sao percorridos sem inflar o conteudo; CRC e
tamanho efetivo sao verificados pelo `archive >=4.6`, inclusive quando
os cabecalhos declaram um tamanho falso. Caminhos inseguros e duplicados
sao rejeitados.
O plano de playback limita a ordem a 10.000 ocorrencias de compasso; acima
disso, a reproducao e bloqueada com diagnostico explicito, sem truncar a
navegacao silenciosamente.

## Demo sem cadastro

```bash
flutter run -t lib/main_score_reader_demo.dart
# Navegador:
flutter run -d chrome -t lib/main_score_reader_demo.dart
# Banco completo servido localmente com CORS:
flutter run -d chrome -t lib/main_score_reader_demo.dart \
  --dart-define=SCORE_SOUNDFONT_KEY=http://127.0.0.1:8782/FluidR3Mono_GM.sf3
```

A entrada usa a tela, controller, parser e motor reais, sem conta nem consulta
ao catalogo. A fixture autoral CC0 tem quatro compassos com notas, letra e
cifras. O banco minimo permite tocar sem rede; o banco completo continua sendo
solicitado sob demanda.

```bash
flutter test --no-pub test/widget/features/score_reader/
```

## Renderizacao e audio

A notacao usa `crisp_notation`/`crisp_notation_core` em Flutter, sem WebView
nem um renderer JavaScript. O modelo, MIDI e sintese sao implementados em
Dart, mas a saida de audio usa `soundfont_kit` com `flutter_soloud`: backend
nativo no mobile e WASM/WebAudio no navegador. Portanto, a cadeia completa
de audio **nao e 100% Dart**.

Um banco SF2 minimo e gerado em memoria. Nao e necessario distribuir um
SoundFont junto do app para tocar imediatamente. O banco General MIDI
completo e buscado sob demanda; falha de download mantem o som minimo e
e reportada pelo estado do leitor.

O SoundFont completo padrao usa a chave
`assets/shared/soundfonts/FluidR3Mono_GM.sf3`. Outra chave ou URL pode ser
definida com `--dart-define=SCORE_SOUNDFONT_KEY=...`.
Na Web, usar a chave do coldigom permite aproveitar o proxy de assets e suas
politicas CORS/CORP. Nao presumir que uma URL externa qualquer funcionara
sob COEP.

Antes de persistir um banco baixado, o repositorio verifica o status HTTP,
o cabecalho SF2/SF3 e os instrumentos/amostras com o parser real.
Um cabecalho de cache corrompido e removido, permitindo voltar ao som minimo.

O carregamento do motor adapta os metadados de loop SF3 para indices PCM,
sem alterar os bytes Ogg ou o banco persistido. Isso evita que offsets de
dados comprimidos sejam usados como posicoes de loop pelo player.

## Controles

Toque numa nota para ouvir uma previa e posicionar o cursor. O transporte
oferece andamento, transposicao de -12 a +12, loop A-B, paginas/continuo e
zoom por botoes ou pinch. A rolagem automatica respeita a interacao manual
e retoma depois de tres segundos. Nas repeticoes, os limites A-B usam
inicio e fim da mesma primeira passagem do compasso.

O mixer oferece GM001-GM128, volume, mute e solo por pauta. O programa do
arquivo e usado quando presente; caso contrario, o padrao e GM001
(programa MIDI 0). Volume inicial e 100%. Com o banco minimo gerado pelo app,
apenas o piano esta disponivel. Se nao houver banco completo em cache, a
primeira reproducao solicita o SoundFont GM completo; uma falha mantem o banco
minimo e aparece como diagnostico. O SoundFont completo padrao e o
FluidR3Mono_GM.sf3 descrito abaixo.

Ha 15 canais MIDI melodicos (o canal de percussao GM e pulado). Sem
acompanhamento de acordes, uma selecao de ate 15 pautas pode ser tocada; com
acompanhamento, ate 14 pautas mais o canal separado de acordes. Quando a
partitura excede esse limite, e preciso escolher as pautas; todas continuam
visiveis. Em partituras com mais de 15 pautas, indices diferentes podem
reutilizar um canal: timbre/programa e volume desse canal ficam compartilhados,
embora mute e solo continuem aplicados por faixa.

## Matriz de sinais e fidelidade do playback

A tabela descreve a conversao MIDI implementada pelo leitor, nao uma promessa
de interpretacao equivalente ao MuseScore ou ao MuseSounds.

| Sinal | Realizacao automatizada | Limites e diagnosticos |
|---|---|---|
| Notas, pausas, vozes e repeticoes | Eventos MIDI por pauta; ligaduras, ordem de repeticoes e navegacao importada de MuseScore/MusicXML alimentam o mesmo plano de tempo. | Destinos nao resolvidos, navegacao conflitante/invalida ou ciclos bloqueiam o playback e geram diagnostico. |
| Andamento | Andamento em seminuas por minuto e mudancas representadas no modelo da partitura. Sem andamento valido, usa-se seminuas = 120 BPM; multiplicador inicial e 1,0 (intervalo 0,25–2). | Valores MusicXML `<sound tempo>` nao sao convertidos para o andamento do plano; se diferirem do andamento ativo, geram diagnostico. Valores invalidos tambem sao diagnosticados. |
| Dinamica | `pppp`, `ppp`, `pp`, `p`, `mp`, `mf`, `f`, `ff`, `fff`, `ffff`, `sf`, `sfz`, `sffz`, `fz`, `rf` e `fp` sao convertidos em velocidade MIDI; sem indicacao, usa-se mf = 80. Velocidade explicita da nota prevalece sobre a velocidade de ataque calculada. Crescendos/decrescendos completos geram uma curva linear de expressao MIDI. | Nomes de dinamica desconhecidos sao informados. Curvas sem nota inicial/final correspondente sao omitidas e diagnosticadas; a curva linear e uma aproximacao, nao uma interpretacao expressiva. |
| Articulacao e fermata | Staccatissimo usa 1/4 da duracao escrita; staccato, 1/2; tenuto, 19/20. Acento soma 15 e marcato 20 a velocidade, limitada a 1–127. Fermata em nota ou pausa reconhecida acrescenta uma duracao escrita ao evento e desloca os eventos seguintes. | Marcacoes de respiracao e direcao de arcada nao sao realizadas e geram diagnostico. As proporcoes sao regras fixas, sem variacao de estilo ou instrumento. |
| Gracas e ornamentos | Gracas acciaccaturas/appoggiaturas, trinados, mordentes e voltas usam os padroes de tempo e altura descritos na secao seguinte. | Nomes de ornamento nao realizados sao diagnosticados e nao recebem um substituto automatico. |
| Arpejo e tremolo | Arpejos ascendentes/descendentes escalonam os ataques dentro da duracao da nota. Tremolos de nota unica com 1–5 golpes subdividem a duracao; MusicXML `single` sem contagem declarada usa 3 golpes. | Tipos MusicXML nao suportados e contagens invalidas ou fora de 1–5 nao sao tocados como tremolo e geram diagnostico. |
| Pedal e acompanhamentos de acordes | Pedal sustentado completo gera CC64 ligado/desligado. O acompanhamento de acordes gera notas simultaneas a partir das cifras parseadas, em faixa/canal separado. | Pares de pedal incompletos sao omitidos e diagnosticados. O acompanhamento nao modela dedilhado, voicing interpretativo ou articulacao de instrumento acustico. |
| Mixer e timbres | Programas GM001–GM128, mute/solo por faixa e volume por canal; a troca de programa atualiza o MIDI da pauta e preserva o estado do transporte. | O som depende do SoundFont GM, do sintetizador/plataforma e do roteamento de canais. Isso nao equivale aos patches, articulacoes, efeitos ou regras de interpretacao do MuseSounds. |

O SoundFont minimo e um piano sintetico gerado pelo app; nao e um conjunto de
instrumentos acusticos. O banco FluidR3Mono GM oferece os programas General
MIDI disponiveis no arquivo, mas nao implementa o motor, os samples nem a
interpretacao do MuseSounds.

Os testes automatizados verificam planos de eventos, temporizacao, mensagens
MIDI/control changes, roteamento e diagnosticos para os sinais cobertos. Eles
nao comparam a saida com o MuseScore/MuseSounds, nao medem fidelidade timbral e
nao substituem audicao ou avaliacao interpretativa humana.

## Ornamentos e gracas

A reproducao realiza trinado, trinado curto, mordente e volta (incluindo a
volta invertida) em alturas diatonicas da tonalidade e dos acidentes ativos no
compasso. Um acidente explicito do ornamento tem prioridade. O trinado alterna
principal e auxiliar em fusas e termina na principal; os outros padroes usam
no maximo a primeira metade da duracao da nota, deixando o restante na
principal sem aumentar o compasso.

Gracas acciaccaturas usam no maximo uma semicolcheia e um quarto da duracao da
nota principal; appoggiaturas usam metade. Multiplas gracas dividem esse tempo
igualmente. Ties de graca a nota principal evitam novo ataque. Parametros
MusicXML `make-time`, `steal-time-following` e `steal-time-previous`, quando
presentes, substituem esses padroes de tempo; `make-time` desloca todas as
pautas e aumenta a duracao do compasso pelo tempo declarado. A reproducao e o
destaque visual continuam associados ao elemento original da partitura.

## Offline

Partituras abertas e o SoundFont completo usam store proprio: filesystem em
`plpcg_scores` no mobile e Cache API `plpcg-scores` na Web. As chaves usam
SHA-256 para distinguir barras/underscores e manter o nome curto, mesmo
quando a chave R2 original ultrapassa o limite de nome do filesystem.

A abertura usa primeiro a copia local; revalidacao de rede fica em background.
Uma nova versao vale a partir da proxima abertura, sem substituir a partitura
durante leitura ou execucao.

Persistencia depende de espaco/quota/permissao da plataforma; as falhas sao
logadas. O download offline em lote so declara a partitura baixada quando
confirma sua presenca no store. 404 e falha de gravacao nao contam como
download concluido. O cancelamento da fila chega a requisicao Dio.

## Distribuicao do SoundFont

O banco completo nao e versionado junto do app. O produtor coldigom ignora
`storage/` no Git e publica esses assets separadamente. Disponibilizar o banco
em `storage/assets/shared/soundfonts/FluidR3Mono_GM.sf3` e sua licenca ao lado
antes de esperar que o download completo funcione em producao.

Origem verificavel:

- [FluidR3Mono_GM.sf3 no MuseScore v3.6.2](https://github.com/musescore/MuseScore/blob/v3.6.2/share/sound/FluidR3Mono_GM.sf3)
- [Licenca e creditos oficiais](https://github.com/musescore/MuseScore/blob/v3.6.2/share/sound/FluidR3Mono_License.md)

Os creditos e a permissao MIT devem acompanhar a distribuicao. A publicacao
do banco e um passo operacional separado, nao executado por testes ou builds.

## Testes direcionados

```bash
flutter test --no-pub test/unit/features/score_reader/
flutter test --no-pub test/unit/features/offline/download_coldigom_materials_test.dart
flutter test --no-pub --platform chrome \
  --dart-define-from-file=dart_defines/plpcjf.json \
  test/web/score_byte_store_web_test.dart
python3 scripts/test_score_audio_web.py
# Opcional: repetir a prova PCM com o banco oficial servido com CORS:
python3 scripts/test_score_audio_web.py test/web/score_audio_engine_web_test.dart \
  --dart-define=SCORE_AUDIO_SF3_URL=http://127.0.0.1:8782/FluidR3Mono_GM.sf3
```

O runner de audio fornece ativacao WebAudio confiavel ao Chrome isolado,
expoe os assets gerados apenas durante o teste e falha em excecoes do
navegador. `scripts/test_all.sh` e o CI usam esse mesmo runner para toda a
suite Chrome, sem excluir os testes reais de audio SF2/SF3. O SF3 minimo de
regressao e autoral; a prova com o banco completo e opcional e nao exige
versionar esse banco.

Testes do controller usam engine falso para tempo/mix deterministas. Eles nao
substituem a prova do engine real, a inspecao visual em navegador/dispositivo
nem a verificacao auditiva humana.
