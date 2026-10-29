# Estudo Crítico das Notas Geradas e Diagnóstico de Materiais Duplicados
> **Data do Relatório:** 28/10/2026
> **Objetivo:** Analisar cada uma das **33 notas distintas** geradas no acervo Coldigom, explicar o motivo exato de sua geração, diagnosticar o problema dos materiais duplicados no acervo (ex.: importação dupla *Avulsos PES* vs *GLTM* em *Deus El Shaday*) e evidenciar notas que são redundantes com a categoria (`material_kind`).

---
## 🔍 1. Confirmação do Diagnóstico do Usuário
A sua suspeita está **totalmente correta em dois aspectos fundamentais**:

### A. Existem Materiais Rigorosamente Duplicados no Acervo (Importação Dupla de Pastas)
- No caso de **Deus El Shaday** (`5ee4d271-6d69-4554-bbfd-10175289c344`), foram importados **47 materiais**, dos quais **38 materiais são 19 pares idênticos** de uma mesma partitura ou áudio.
- A pasta inteira `Avulsos PES/Deus El Shaday/` e a pasta inteira `GLTM/Deus el Shaday/` foram ambas processadas e inseridas no mesmo louvor!
- Como o motor de notas viu 2 arquivos de cada instrumento (`Flute.pdf` vs `Flute.pdf`, `Trombone.pdf` vs `Trombone.pdf`), ele considerou que se tratava de vozes complementares e atribuiu `I` a um e `II` ao outro, quando na verdade **são a mesmíssima partitura enviada duas vezes**.

### B. Redundância entre a Nota e o `material_kind`
- O motor de anotação procurou termos textuais (`soprano`, `contralto`, `tenor`, `baixo`, `playback`) no nome do arquivo **sem validar se a categoria do material já era essa mesma voz**.
- **Consequência no App:** O usuário vê na tela:
  - `Voz baixo [Baixo]` (o material kind já é Voz Baixo!)
  - `Voz soprano [Soprano]` (o material kind já é Voz Soprano!)
  - `Voz tenor [Tenor]` (o material kind já é Voz Tenor!)
  - `Voz contralto [Contralto]` (o material kind já é Voz Contralto!)
  - `Playback [Playback]` (o material kind já é Playback!)
- **Falsos positivos por colisão de palavras:**
  - `Saxofone soprano` recebeu a nota `Soprano` porque o arquivo chamava `Soprano Saxophone.pdf` (um instrumento recebendo tag de naipe vocal!).
  - `Contra Bass` (contrabaixo de cordas) recebeu a nota `Baixo` porque o arquivo continha 'bass'.

---

## 📊 2. Catálogo Completo das 33 Notas Distintas: Motivo e Diagnóstico

| # | Nota | Qtd | Louvores | Principais Categorias Afetadas | Por que foi gerada? (Regra) | Avaliação Crítica |
|---|---|:---:|:---:|---|---|---|
| 1 | **`I`** | 1974 | 663 | Coro (289), Partitura (211) | Primeiro item da ordenação natural em clusters de múltiplos materiais do mesmo kind. | ✅ Legítima para instrumentos com vozes reais (ex: Trompete I e II), mas ⚠️ Falsa para arquivos duplicados por importação dupla. |
| 2 | **`II`** | 1965 | 660 | Coro (288), Partitura (211) | Segundo item da ordenação natural em clusters de múltiplos materiais. | ✅ Legítima para vozes reais; ⚠️ Falsa para duplicatas exatas. |
| 3 | **`III`** | 195 | 112 | Coro (74), Áudio (19) | Terceiro item da ordenação natural de instrumentos/partes. | ✅ Legítima para naipes com 3 partes (ex: Clarinete III, Trombone III). |
| 4 | **`Geral`** | 139 | 91 | Áudio (122), MIDI geral (12) | Detectou termo 'geral' ou 'todos' em faixas de áudio/MIDI. | ✅ Legítima quando o kind é 'Áudio' para diferenciar a mixagem completa das vozes solo. |
| 5 | **`Soprano`** | 120 | 59 | Voz soprano (69), Saxofone soprano (18) | Detectou termo 'soprano' no arquivo. | ❌ Quase sempre REDUNDANTE (o kind já é Voz Soprano) ou FALSO POSITIVO (Sax soprano). |
| 6 | **`Baixo`** | 99 | 50 | Voz baixo (61), MIDI baixo (17) | Detectou termo 'baixo' no arquivo. | ❌ Quase sempre REDUNDANTE (o kind já é Voz Baixo) ou FALSO POSITIVO (Contra Bass). |
| 7 | **`Contralto`** | 96 | 52 | Voz contralto (65), MIDI contralto (13) | Detectou termo 'contralto' no arquivo. | ❌ Quase sempre REDUNDANTE (o kind já é Voz Contralto). Só faz sentido se for Contralto I/II. |
| 8 | **`Tenor`** | 80 | 44 | Voz tenor (56), Áudio (10) | Detectou termo 'tenor' no arquivo. | ❌ Quase sempre REDUNDANTE (o kind já é Voz Tenor). Só faz sentido se for Tenor I/II. |
| 9 | **`IV`** | 54 | 44 | Coro (26), Áudio (11) | Quarto item da ordenação natural de instrumentos/partes. | ✅ Legítima para naipes com 4 partes (ex: Trompas I a IV). |
| 10 | **`Tenor II`** | 47 | 31 | Voz tenor (27), MIDI tenor (8) | Detectou numeração explícita da voz (Tenor II). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 11 | **`Tenor I`** | 46 | 31 | Voz tenor (27), MIDI tenor (7) | Detectou numeração explícita da voz (Tenor I). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 12 | **`Contralto II`** | 38 | 26 | Voz contralto (21), MIDI contralto (6) | Detectou numeração explícita da voz (Contralto II). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 13 | **`Contralto I`** | 34 | 25 | Voz contralto (20), MIDI contralto (6) | Detectou numeração explícita da voz (Contralto I). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 14 | **`Ensaio`** | 31 | 31 | Áudio (27), Voz cantada (3) | Detectou termo 'ensaio' ou 'versão ensaio' no arquivo de áudio. | ✅ Legítima. Diferencia a gravação de ensaio do áudio final. |
| 15 | **`Playback`** | 30 | 16 | Playback (30) | Detectou termo 'playback' no nome do arquivo. | ⚠️ Redundante se o kind já for 'Playback'; útil se o kind for 'Áudio'. |
| 16 | **`Soprano I`** | 18 | 16 | Voz soprano (12), MIDI soprano (3) | Detectou numeração explícita da voz (Soprano I). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 17 | **`I e II`** | 17 | 9 | Flauta (3), Saxofone alto (3) | Detectou regex '1 e 2', '1-2', '1&2' no nome do arquivo. | ✅ Excelente. Indica parte dobrada no mesmo papel (ex: Clarinet 1-2). |
| 18 | **`Soprano II`** | 16 | 14 | Voz soprano (11), MIDI soprano (3) | Detectou numeração explícita da voz (Soprano II). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 19 | **`V`** | 16 | 16 | Áudio (8), Coro (5) | Quinto item em clusters com 5 arquivos. | ⚠️ Quase sempre indica agrupamento genérico ou partituras acumuladas. |
| 20 | **`Grade`** | 15 | 10 | Coro (8), MIDI instrumentos (2) | Detectou termo 'grade' sob categoria de Coro/Partitura. | ✅ Legítima. Identifica a grade geral quando misturada a partes. |
| 21 | **`VI`** | 12 | 7 | Áudio (4), Coro (4) | Sexto item em clusters com 6 arquivos. | ⚠️ Agrupamento amplo sob uma mesma categoria. |
| 22 | **`Baixo II`** | 10 | 9 | Voz baixo (9), MIDI baixo (1) | Detectou numeração explícita da voz (Baixo II). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 23 | **`Solo`** | 10 | 7 | Áudio (4), Coro (3) | Detectou termo 'solo' no arquivo de áudio ou partitura vocal. | ✅ Legítima. Indica trecho/faixa exclusiva do solista. |
| 24 | **`Baixo I`** | 9 | 8 | Voz baixo (8), MIDI baixo (1) | Detectou numeração explícita da voz (Baixo I). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 25 | **`Guia Vocal`** | 5 | 5 | Áudio (3), Coro (1) | Detectou termo 'guia' ou 'guia vocal' no áudio. | ✅ Legítima. Diferencia faixa com guia cantada. |
| 26 | **`Simplificada`** | 5 | 4 | Cifra (2), Viola (1) | Detectou termo 'simplificada' ou 'iniciante' na partitura/cifra. | ✅ Legítima. Útil para músicos iniciantes. |
| 27 | **`Clarone`** | 3 | 3 | Clarinete em Si bemol (2), Clarinete (1) | Detectou 'bass clarinet' ou 'clarone' sob Clarinete. | ✅ Legítima até que Clarone vire material_kind próprio. |
| 28 | **`Cifrado`** | 2 | 2 | Baixo elétrico (1), Coro (1) | Detectou 'cifrado' em partitura de Coro ou Baixo. | ✅ Legítima. Diferencia a partitura cifrada da partitura pura. |
| 29 | **`Iniciante`** | 2 | 1 | Viola (1), Violoncelo (1) | Detectou termo 'iniciante' na partitura de cordas. | ✅ Legítima. Arranjo facilitado. |
| 30 | **`Piano`** | 2 | 2 | Violoncelo (1), Base (1) | Detectou 'piano' em material de base/violoncelo. | ✅ Legítima para instrumentos combinados. |
| 31 | **`Contralto III`** | 1 | 1 | Voz contralto (1) | Detectou numeração explícita da voz (Contralto III). | ✅ Altamente funcional e necessária para diferenciar divisões do naipe vocal. |
| 32 | **`II e III`** | 1 | 1 | Trompete (1) | Detectou regex '2 e 3', '2-3' no nome do arquivo. | ✅ Excelente. Parte dobrada para 2º e 3º músicos (ex: Trumpet 2-3). |
| 33 | **`VII`** | 1 | 1 | Coro (1) | Sétimo item em cluster com 7 arquivos. | ⚠️ Caso isolado em cluster genérico. |

---

## 🔬 3. Estudo de Caso Aprofundado: Deus El Shaday
🔗 **Link no Coldigom Web:** [https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344)

Neste louvor existem **47 materiais cadastrados**. Observe a tabela completa abaixo:
Quase todos os instrumentos e vozes aparecem **duas vezes**, uma vinda da pasta `GLTM/Deus el Shaday/` e outra da pasta `Avulsos PES/Deus El Shaday/`:

| Categoria (Kind) | Tipo | Nota Gerada | Origem e Nome do Arquivo | ID do Material (Abrir no Coldigom) |
|---|:---:|:---:|---|:---:|
| Cifra | pdf | *sem nota* | `plpcg:Avulsos/.../255.pdf` | [20564fb3...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=20564fb3-f01d-4085-93ec-9db232ba647b#material-20564fb3-f01d-4085-93ec-9db232ba647b) |
| Clarinete em Si bemol | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Clarinet in Bb.pdf` | [792e36ab...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=792e36ab-cf90-4199-95c0-b30410288b20#material-792e36ab-cf90-4199-95c0-b30410288b20) |
| Clarinete em Si bemol | pdf | `I` | `GLTM/.../Deus El Shaday - Clarinet in Bb.pdf` | [f2631b1a...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=f2631b1a-cef0-4a28-8c02-d3010b127d32#material-f2631b1a-cef0-4a28-8c02-d3010b127d32) |
| Coro | pdf | `II` | `Avulsos PES/.../Deus_El_Shaday_-_Vocal.pdf` | [24fe717d...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=24fe717d-a844-4772-9efb-5725fed10eeb#material-24fe717d-a844-4772-9efb-5725fed10eeb) |
| Coro | pdf | `I` | `GLTM/.../Deus El Shaday - Vocal.pdf` | [df9c7284...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=df9c7284-69b5-47c8-a318-7f4789c3b454#material-df9c7284-69b5-47c8-a318-7f4789c3b454) |
| Coro e piano | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Vocal e Piano.pdf` | [91297316...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=91297316-69a6-4846-8225-38aac14c77da#material-91297316-69a6-4846-8225-38aac14c77da) |
| Coro e piano | pdf | `I` | `GLTM/.../Deus El Shaday - Vocal e Piano.pdf` | [5d5fda5e...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=5d5fda5e-2700-477a-88b2-5cdcb8850b9e#material-5d5fda5e-2700-477a-88b2-5cdcb8850b9e) |
| Fagote | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Bassoon.pdf` | [183eb93c...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=183eb93c-e98a-4e08-8115-3294c6d5f484#material-183eb93c-e98a-4e08-8115-3294c6d5f484) |
| Fagote | pdf | `I` | `GLTM/.../Deus El Shaday - Bassoon.pdf` | [b918f3ac...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=b918f3ac-dc80-4778-afa8-86b9e54b1837#material-b918f3ac-dc80-4778-afa8-86b9e54b1837) |
| Flauta | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Flute.pdf` | [e3e253f4...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=e3e253f4-dd6f-45d3-af95-5cbcb67514d3#material-e3e253f4-dd6f-45d3-af95-5cbcb67514d3) |
| Flauta | pdf | `I` | `GLTM/.../Deus El Shaday - Flute.pdf` | [ff9a44b3...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=ff9a44b3-b3d7-446f-92f4-296efce3a5a4#material-ff9a44b3-b3d7-446f-92f4-296efce3a5a4) |
| Grade | pdf | `II` | `Avulsos PES/.../Deus_El_Shaday_-_Grade.pdf` | [3d62f386...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=3d62f386-bd5d-4655-8eca-070daeca5261#material-3d62f386-bd5d-4655-8eca-070daeca5261) |
| Grade | pdf | `I` | `GLTM/.../Deus El Shaday - Grade.pdf` | [42f260bb...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=42f260bb-6c81-4f40-8cdf-ebf9a1e90368#material-42f260bb-6c81-4f40-8cdf-ebf9a1e90368) |
| MIDI baixo | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - Baixo.mp3` | [f26d2778...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=f26d2778-13de-472e-bdf9-a2b15ce01a4e#material-f26d2778-13de-472e-bdf9-a2b15ce01a4e) |
| MIDI contralto | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - Contralto.mp3` | [f264d77f...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=f264d77f-25ae-49b0-8fbe-775fe9f2af83#material-f264d77f-25ae-49b0-8fbe-775fe9f2af83) |
| MIDI soprano | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - Soprano.mp3` | [6dd5a442...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=6dd5a442-e12a-456b-9901-fd69c1143be9#material-6dd5a442-e12a-456b-9901-fd69c1143be9) |
| MIDI tenor | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - Tenor.mp3` | [92166e98...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=92166e98-9f01-4e58-8545-e950b73bde9e#material-92166e98-9f01-4e58-8545-e950b73bde9e) |
| Oboé | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Oboe.pdf` | [201dc2b3...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=201dc2b3-5944-4411-841b-9d3a68bd3e33#material-201dc2b3-5944-4411-841b-9d3a68bd3e33) |
| Oboé | pdf | `I` | `GLTM/.../Deus El Shaday - Oboe.pdf` | [9161b0b7...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=9161b0b7-fef4-49d0-b0c1-b59d0fdeb841#material-9161b0b7-fef4-49d0-b0c1-b59d0fdeb841) |
| Piano | mp3 | *sem nota* | `GLTM/.../ÁUDIO - Deus El Shaday - Piano.mp3` | [6c462106...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=6c462106-b157-4358-a3dc-1aae63fba829#material-6c462106-b157-4358-a3dc-1aae63fba829) |
| Saxofone alto | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Alto Sax.pdf` | [f7c922a9...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=f7c922a9-795a-4395-8ddb-499d7cdfaa70#material-f7c922a9-795a-4395-8ddb-499d7cdfaa70) |
| Saxofone alto | pdf | `I` | `GLTM/.../Deus El Shaday - Alto Sax.pdf` | [3ae1cfb1...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=3ae1cfb1-cbff-45fe-9bff-a4880699bcae#material-3ae1cfb1-cbff-45fe-9bff-a4880699bcae) |
| Saxofone tenor | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Tenor Sax.pdf` | [34ee8688...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=34ee8688-b508-4804-8463-4c0d44790dc9#material-34ee8688-b508-4804-8463-4c0d44790dc9) |
| Saxofone tenor | pdf | `I` | `GLTM/.../Deus El Shaday - Tenor Sax.pdf` | [403d376e...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=403d376e-3a01-440e-a122-e83161be303b#material-403d376e-3a01-440e-a122-e83161be303b) |
| Trombone | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Trombone.pdf` | [8bbce12d...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=8bbce12d-a601-4275-ab4b-2a34bd7fc987#material-8bbce12d-a601-4275-ab4b-2a34bd7fc987) |
| Trombone | pdf | `I` | `GLTM/.../Deus El Shaday - Trombone.pdf` | [c6c95622...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=c6c95622-25f6-4375-9ce7-c9d429775f7e#material-c6c95622-25f6-4375-9ce7-c9d429775f7e) |
| Trompete em Si bemol | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Trumpet in Bb.pdf` | [1dfc32d1...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=1dfc32d1-734d-47af-b066-c3e5c5ba3072#material-1dfc32d1-734d-47af-b066-c3e5c5ba3072) |
| Trompete em Si bemol | pdf | `I` | `GLTM/.../Deus El Shaday - Trumpet in Bb.pdf` | [8ee87f5a...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=8ee87f5a-cd44-4aa1-b8b2-35eaa95cbd6e#material-8ee87f5a-cd44-4aa1-b8b2-35eaa95cbd6e) |
| Viola | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Viola.pdf` | [de4b98a5...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=de4b98a5-589f-4979-9496-afaee6182f7f#material-de4b98a5-589f-4979-9496-afaee6182f7f) |
| Viola | pdf | `I` | `GLTM/.../Deus El Shaday - Viola.pdf` | [f56fe695...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=f56fe695-6f7c-4a83-9835-3987c50c9eca#material-f56fe695-6f7c-4a83-9835-3987c50c9eca) |
| Violino I | pdf | `I` | `Avulsos PES/.../Deus El Shaday - Violin I.pdf` | [a48b689d...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=a48b689d-8d5b-45be-8445-7337ace4861c#material-a48b689d-8d5b-45be-8445-7337ace4861c) |
| Violino I | pdf | `I` | `GLTM/.../Deus El Shaday - Violin I.pdf` | [daf4f512...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=daf4f512-2bb5-4cd0-9769-2194a72a560b#material-daf4f512-2bb5-4cd0-9769-2194a72a560b) |
| Violino II | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Violin II.pdf` | [e5f6a53c...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=e5f6a53c-9b36-4a97-8ac1-546f8c1ce4da#material-e5f6a53c-9b36-4a97-8ac1-546f8c1ce4da) |
| Violino II | pdf | `II` | `GLTM/.../Deus El Shaday - Violin II.pdf` | [6e2c8a10...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=6e2c8a10-2b2b-49ce-80f4-9a94d0d3082f#material-6e2c8a10-2b2b-49ce-80f4-9a94d0d3082f) |
| Violoncelo | pdf | `II` | `Avulsos PES/.../Deus El Shaday - Cello.pdf` | [66a7d783...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=66a7d783-f016-43e8-b502-0f54a3405fa9#material-66a7d783-f016-43e8-b502-0f54a3405fa9) |
| Violoncelo | pdf | `I` | `GLTM/.../Deus El Shaday - Cello.pdf` | [d203099e...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=d203099e-2845-498f-a5ca-70c59d8b3b20#material-d203099e-2845-498f-a5ca-70c59d8b3b20) |
| Voz baixo | mp3 | `Baixo` | `Avulsos PES/.../Deus El Shaday - Baixo.mp3` | [0830b320...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=0830b320-09dd-4b28-8a03-74175f5a54f3#material-0830b320-09dd-4b28-8a03-74175f5a54f3) |
| Voz baixo | mp3 | `Baixo` | `GLTM/.../VOZ - Deus El Shaday - Baixo.mp3` | [6196766a...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=6196766a-c9f8-4503-9ee7-6acab47e565f#material-6196766a-c9f8-4503-9ee7-6acab47e565f) |
| Voz contralto | mp3 | *sem nota* | `GLTM/.../VOZ - Deus El Shaday - Contralto.mp3` | [058a9450...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=058a9450-343b-4c69-8f8f-5f540f0cf145#material-058a9450-343b-4c69-8f8f-5f540f0cf145) |
| Voz contralto I | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - 1° Contralto .mp3` | [c878fb37...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=c878fb37-f6b1-4da2-8605-fb6da5d8af56#material-c878fb37-f6b1-4da2-8605-fb6da5d8af56) |
| Voz contralto II | mp3 | *sem nota* | `Avulsos PES/.../Deus El Shaday - 2° Contralto.mp3` | [a606e612...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=a606e612-88c3-410c-be8c-d7106fd8a22d#material-a606e612-88c3-410c-be8c-d7106fd8a22d) |
| Voz soprano | mp3 | `Soprano` | `Avulsos PES/.../Deus El Shady - Soprano.mp3` | [a2107620...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=a2107620-13fc-4254-b2bd-c905b42dd416#material-a2107620-13fc-4254-b2bd-c905b42dd416) |
| Voz soprano | mp3 | `Soprano` | `GLTM/.../VOZ - Deus El Shaday - Soprano.mp3` | [ae3f9729...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=ae3f9729-3764-4e5d-869e-715ea12146f2#material-ae3f9729-3764-4e5d-869e-715ea12146f2) |
| Voz tenor | mp3 | `Tenor` | `Avulsos PES/.../Deus El Shaday - Tenor.mp3` | [828a62f2...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=828a62f2-ce1e-4362-a580-7e26513253f2#material-828a62f2-ce1e-4362-a580-7e26513253f2) |
| Voz tenor | mp3 | `Tenor` | `GLTM/.../VOZ- Deus El Shaday - Tenor.mp3` | [7cf64ad1...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=7cf64ad1-bc30-4d1b-b119-181fb448c491#material-7cf64ad1-bc30-4d1b-b119-181fb448c491) |
| Áudio | mp3 | `Geral` | `GLTM/.../ÁUDIO - Deus El Shaday - Todos.mp3` | [3ea73654...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=3ea73654-0e16-4d1d-ad46-8a184968b2e0#material-3ea73654-0e16-4d1d-ad46-8a184968b2e0) |
| Áudio | mp3 | `Ensaio` | `GLTM/.../ÁUDIO - Deus El Shaday - Versão Ensaio.mp3` | [d4a9e756...](https://coldigom-web.pages.dev/praise/5ee4d271-6d69-4554-bbfd-10175289c344?materialId=d4a9e756-0617-4aa7-b883-63c4205909ab#material-d4a9e756-0617-4aa7-b883-63c4205909ab) |

### 💡 O que aconteceu em Deus El Shaday?
1. **Duplicatas Espelhadas de Arquivo:**
   - `Clarinete em Si bemol`: Existem 2 arquivos com o mesmo nome `Deus El Shaday - Clarinet in Bb.pdf`. Um veio de GLTM e outro de Avulsos PES. Eles ganharam as notas `I` e `II`, dando a falsa impressão de serem duas vozes orquestrais, quando na verdade são o mesmo arquivo!
   - O mesmo aconteceu para: Flauta, Trombone, Trompete, Sax Alto, Sax Tenor, Fagote, Oboé, Viola, Violoncelo, Grade e Coro.
2. **Vozes Cantadas com Tags Redundantes:**
   - `Voz baixo`: recebeu nota `Baixo` em ambos os arquivos (`Avulsos PES` e `GLTM`).
   - `Voz soprano`: recebeu nota `Soprano` em ambos os arquivos.
   - `Voz tenor`: recebeu nota `Tenor` em ambos os arquivos.
3. **Áudios de Ensaio:**
   - Sob a categoria genérica `Áudio`, um arquivo chamava `ÁUDIO - Deus El Shaday - Todos.mp3` (recebeu `Geral`) e outro `ÁUDIO - Deus El Shaday - Versão Ensaio.mp3` (recebeu `Ensaio`). Aqui, **a nota faz total sentido**, pois a categoria é apenas 'Áudio'.

---

## 📂 4. Outros Louvores com Importação Espelhada Idêntica
Identificamos **43 louvores** na base com o mesmíssimo comportamento de *Deus El Shaday* (onde arquivos com exatamente o mesmo nome foram inseridos a partir de pastas de origem diferentes):

- **A Ti Senhor**: 1 categorias duplicadas espelhadas (ex.: Choir (2x))
- **A oração da Tua igreja**: 1 categorias duplicadas espelhadas (ex.: Choir (2x))
- **A vitória da igreja**: 1 categorias duplicadas espelhadas (ex.: Chord Chart (2x))
- **Com meu coração**: 1 categorias duplicadas espelhadas (ex.: Strings (2x))
- **Conheçamos e prossigamos**: 1 categorias duplicadas espelhadas (ex.: Chord Chart (3x))
- **Creio neste Deus**: 12 categorias duplicadas espelhadas (ex.: Flute (4x), Clarinet (2x), French Horn in F (2x), Bassoon (2x))
- **Cristo cura, sim**: 11 categorias duplicadas espelhadas (ex.: Flute (2x), Bassoon (2x), Oboe (2x), Viola (2x))
- **Deus El Shaday**: 13 categorias duplicadas espelhadas (ex.: Violin I (2x), Flute (2x), Trumpet in Bb (2x), Bassoon (2x))
- **Deus é Nosso Refúgio (God is our Refuge)**: 1 categorias duplicadas espelhadas (ex.: Cello (2x))
- **Digno é o Cordeiro**: 3 categorias duplicadas espelhadas (ex.: Viola (2x), Trombone (2x), Choir (3x))
- **E veio a mim**: 22 categorias duplicadas espelhadas (ex.: Violin I (2x), Flute (2x), Trumpet in Bb (2x), Soprano Voice (3x))
- **Em caminhos de dor**: 14 categorias duplicadas espelhadas (ex.: Violin I (2x), Flute (2x), Trumpet in Bb (2x), Lyrics (2x))
- **Eu Clamo Pelo Sangue de Jesus**: 1 categorias duplicadas espelhadas (ex.: Choir (2x))
- **Eu tenho um Pai (Adoção)**: 16 categorias duplicadas espelhadas (ex.: Violin I (3x), Flute (3x), Trumpet in Bb (3x), French Horn in F (3x))
- **É lindo, é lindo, sim**: 11 categorias duplicadas espelhadas (ex.: Flute (2x), Trumpet in Bb (2x), Bassoon (2x), Oboe (2x))

---

## 🛠️ 5. Plano de Ação Recomendado

Para deixar o sistema limpo, elegante e sem redundâncias:

1. **Eliminar Notas Redundantes com o `material_kind`:**
   - Se `material_kind` for `Voz baixo`, `Voz soprano`, `Voz tenor` ou `Voz contralto`:
     - **NUNCA** atribuir a nota da própria voz (`Baixo`, `Soprano`, etc.).
     - Só atribuir nota se houver subdivisão explícita: `Contralto I`, `Contralto II`, `Tenor I`, `Tenor II`, etc.
   - Se `material_kind` for `Saxofone soprano`, **NUNCA** atribuir a nota `Soprano`.
   - Se `material_kind` for `Playback`, **NUNCA** atribuir a nota `Playback`.

2. **Tratar Duplicatas Exatas de Arquivo (Deduplicação / Limpeza):**
   - Nos louvores com importação dupla espelhada (como *Deus El Shaday* e *Lugar da Oração*), os materiais duplicados de GLTM vs Avulsos PES devem ser unificados (mantendo apenas uma cópia e removendo a cópia excedente).
   - Enquanto não forem deduplicados, eles não devem se passar por `I` e `II` (que fingem ser vozes orquestrais 1 e 2).

3. **Onde as Notas Devem Realmente Existir:**
   - **Partes Orquestrais:** `Flauta I` e `Flauta II`, `Trompete I`, `II` e `II e III` (quando o arranjo realmente tem múltiplos instrumentos).
   - **Subdivisões Vocais:** `Contralto I` e `Contralto II`.
   - **Faixas sob Categoria Genérica 'Áudio':** `Geral`, `Ensaio`, `Guia Vocal`, `Solo`.
   - **Variantes de Partitura:** `Cifrado`, `Grade`, `Simplificada`.
