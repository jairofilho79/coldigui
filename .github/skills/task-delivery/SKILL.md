---
name: task-delivery
description: 'Use ao iniciar e finalizar tarefas no coldigui: criar branch feature/ ou fix/, incrementar minor/patch e build, preparar commit e PR, solicitar aprovacao de merge na main protegida e oferecer deploy completo ou com skips de web, android e ios.'
---

# Entrega de tarefas do coldigui

## Antes de implementar

1. Apresente entendimento, DoR/DoD e aguarde aprovacao. Consultas sem alteracoes
   nao entram neste fluxo. Classifique como `feature` ou `fix`; se houver duvida,
   pergunte. Mudancas incompativeis exigem discutir a versao major, nao rotula-las
   silenciosamente como feature.
2. Examine a branch e alteracoes existentes com ferramentas de leitura. Nunca
   descarte, esconda com stash ou inclua trabalho preexistente automaticamente.
   Em clone limpo na `main`, sincronize com `git pull --ff-only origin main`.
   O comando start consulta `origin/main` e exige HEAD igual a base remota.
   Se houver commits locais ainda nao publicados, nao os envie junto da tarefa:
   proponha uma worktree isolada de `origin/main`, preservando o trabalho atual.
3. Crie e registre a branch **antes** das alteracoes:

   ```bash
   python3 scripts/task_delivery.py start feature descricao-curta
   # ou:
   python3 scripts/task_delivery.py start fix descricao-curta
   ```

   Use `--allow-dirty` somente depois de revisar a propriedade das alteracoes e
   obter permissao para preserva-las na mesma worktree. Nao autoriza comita-las.
   Para uma branch ja criada exclusivamente para a tarefa, ainda na base remota
   e antes do primeiro commit, use `--adopt` com o mesmo tipo/slug.
   Repetir start com --adopt nao reinicia o versionamento.
   Para outra tarefa, use outra branch a partir da `main`; nao reutilize o PR.
4. Em novo clone, instale os hooks Git:

   ```bash
   python3 scripts/task_delivery.py install
   ```

   Havendo hooks existentes, interrompa e integre com aprovacao; nao sobrescreva.
   Requer Git e Python 3.9+ no macOS/Linux. GitHub requer `gh` autenticado.

## Ao concluir uma tarefa

1. Verifique o DoD e rode os testes pertinentes. Para esta automacao:

   ```bash
   python3 -B -m unittest discover -s scripts -p test_task_delivery.py
   ```

   Para mudancas Flutter, siga os comandos de teste documentados no README.
   Se houver falha, nao declare sucesso nem prepare entrega como validada.
2. Prepare a versao em `pubspec.yaml` **uma unica vez por branch/tarefa**:

   ```bash
   python3 scripts/task_delivery.py prepare
   ```

   `feature`: `1.3.8+6` -> `1.4.0+7`; `fix`: `1.3.8+6` -> `1.3.9+7`.
   O build sempre aumenta. Flutter propaga essa fonte para Android/iOS;
   nao edite versoes nativas manualmente. Confira a diferenca e valide novamente
   o necessario. Repetir prepare e seguro; nao incrementa novamente.
   Se houver versao inesperada ou a main tiver avancado alterando a versao,
   interrompa, atualize/reconcilie a branch e o versionamento explicitamente;
   nunca edite o estado local para ocultar o conflito. Se a entrega ja estiver
   preparada, siga a reconciliacao abaixo para herdar a versao da main.
3. Revise as diferencas e segredos. Adicione **caminhos explicitos** ao stage;
   nunca `git add .` ou `git add -A`. Nao comite arquivos alheios a tarefa.
   Revise `git diff --cached`. Use o fluxo de commit vigente e Conventional
   Commits (`feat:`/`fix:`), incluindo o trailer de coautoria exigido pelo ambiente.
4. Envie somente esta branch e crie/reutilize seu PR para `main` com `gh`.
   Registre o numero:

   ```bash
   python3 scripts/task_delivery.py finish 42
   ```

   O comando verifica repositorio, base, branch, versao comitada, PR aberto e HEAD
   remoto igual ao local. Nao faz merge nem deploy. Repetir nao duplica PR.
   Informe URL, versao, testes e pendencias ao usuario.
5. Se o PR nao puder ser criado/validado, informe o bloqueio; nao finja entrega.
   O hook de parada lembra uma vez quando a tarefa esta preparada. Ele nao
   transforma qualquer resposta em tarefa concluida e nao entra em loop.

## Retomar uma correcao da mesma entrega

Depois de `finish`, uma falha de CI ou feedback da mesma tarefa pode exigir
alteracoes. Obtenha aprovacao para esse escopo e, na branch registrada, execute:

```bash
python3 scripts/task_delivery.py resume 42 --reason "Corrigir o CI da mesma entrega"
```

O comando verifica o PR registrado, aberto em `jairofilho79/coldigui`, com base
`main`, branch e HEAD remoto iguais aos locais e versao preparada ja comitada.
Alteracoes nao comitadas em `pubspec.yaml` impedem a retomada; outros arquivos
preexistentes continuam exigindo revisao de propriedade e nao devem ser incluidos.
PR fechado/mesclado, outro PR ou divergencia de HEAD nao reabrem a tarefa.

A fase volta para `prepared`, libera os editores e registra motivo e HEAD da
retomada. A versao permanece a mesma: `prepare` nao incrementa novamente.
Repetir `resume` com o mesmo PR e seguro. Valide a correcao, comite somente seus
caminhos, envie a branch, atualize o PR existente e execute `finish` novamente.
Isso nao autoriza merge: um novo HEAD exige nova aprovacao explicita.

O workflow Web executa os testes da automacao e usa Chrome Stable como referencia
do gate de boot, nao o snapshot de desenvolvimento `latest` da action.
Os limites de performance e as demais verificacoes permanecem inalterados.

Nao use a retomada para outra tarefa; nesse caso, comece outra branch da `main`.
Nao altere o estado local nem desative hooks para liberar edicoes.

## Reconciliar a versao apos integrar main

Se a main recebeu outra entrega enquanto este PR estava aberto, obtenha aprovacao
para resolver os conflitos. Retome a entrega com `resume` antes de editar,
integre `origin/main` na branch do PR e preserve a versao ja publicada na main,
sem novo incremento. Depois de resolver e comitar a integracao, execute:

```bash
python3 scripts/task_delivery.py reconcile-version --reason "Preservar a versao integrada na main"
```

O comando exige fase `prepared`, motivo nao vazio e `pubspec.yaml` sem mudancas
pendentes. Atualiza a referencia remota e verifica que `origin/main` e ancestral
do HEAD e que a versao comitada coincide com ela. Rejeita downgrade semantico ou
de build. Nao escreve no pubspec nem incrementa a versao; registra o commit de
origem e o motivo, preservando a base original da tarefa. Esse commit e sua
versao sao revalidados ao carregar o estado. Repetir o comando ou `prepare` nao
incrementa novamente.

Valide as alteracoes, publique a branch e execute `finish` no mesmo PR.
As verificacoes de PR aberto, repositorio, branch e HEAD remoto continuam
obrigatorias. Reconciliacao nao autoriza merge nem deploy.

## Merge: aprovacao separada e vinculada ao PR

1. Consulte PR, diff, HEAD e checks:
   `gh pr view <numero> --repo jairofilho79/coldigui` e `gh pr checks <numero>`.
   Os jobs `web` e `worker` continuam executando, mas nao sao obrigatorios para
   o merge. Informe ao usuario seus resultados ou se estao pendentes, juntamente
   com os testes locais realizados e eventuais falhas ou limitacoes. Resolva
   conflitos antes do merge; checks que venham a ser configurados como
   obrigatorios devem estar verdes.
2. Mostre o numero/URL e SHA atual e solicite aprovacao explicita usando a
   ferramenta de perguntas. Nao interprete aprovacao da implementacao como
   aprovacao de merge. Sem resposta, negacao ou cancelamento: nao faca merge.
3. A aprovacao vale somente para esse PR e HEAD. Se o HEAD mudar, pergunte
   novamente. Execute somente apos aprovacao:

   ```bash
   gh pr merge <numero> --repo jairofilho79/coldigui --squash --match-head-commit <SHA-aprovado>
   ```

   Nunca use `--admin`, `--auto`, desative workflows ou altere protecoes para
   contornar uma falha. A protecao remota exige PR inclusive para administradores;
   os jobs opcionais nao sao uma garantia de validacao antes do merge.
   A aprovacao conversacional e uma regra da skill; ela nao e um review GitHub
   autenticado e nao e comprovada pelo hook.
4. Confirme estado `MERGED` pelo GitHub antes de oferecer execucao de deploy.

## Deploy: somente com outra autorizacao

Ofereca: completo; skips combinaveis `web`, `android`, `ios`; ou nao executar.
Mostre o comando correspondente e aguarde a escolha explicita. Nunca execute
deploy dentro de hooks. Se todas as plataformas forem excluidas, nao execute.

```bash
./deploy.sh
./deploy.sh --skip-web
./deploy.sh --skip-android --skip-ios
```

O fluxo existente publica Web no Cloudflare Pages e faz homologacao nos
dispositivos mobile; **nao publica nas lojas**. Antes de executar, use o commit
efetivamente integrado na `main`, em worktree limpa. Nao rode sobre alteracoes
locais ou codigo de outro PR. Se a worktree estiver suja, interrompa e explique;
nao descarte/stash automaticamente. Nao aumente a versao novamente no deploy.

## Estado, protecoes e ativacao

- Estado por branch e lock ficam no diretorio Git (`task-delivery/`), nunca no
  stage. `python3 scripts/task_delivery.py status` mostra a fase e versao.
- Hooks Copilot usam `sessionStart`, `preToolUse` e `agentStop`, no formato
  documentado em https://docs.github.com/en/copilot/reference/hooks-reference.
- O hook de ferramentas bloqueia editores conhecidos e shell sem tarefa
  registrada. Permite comandos literais de consulta, start, volta a main e
  atualizacao fast-forward. Deploy direto requer main limpa e retorna `ask`,
  nunca `allow`. Nao aprova outras permissoes automaticamente. Apos finish,
  editores ficam bloqueados ate a retomada explicita da mesma entrega; shell
  permanece disponivel para consultar/retomar/mesclar PR e fazer o deploy autorizado.
- Os hooks Git bloqueiam commit/merge local na main e pushes cujo destino seja
  main, independentemente do nome da branch de origem. Hooks locais podem ser
  contornados por outras ferramentas ou `--no-verify`; nao sao uma sandbox.
  A protecao GitHub e a barreira remota.
- Inicie uma nova sessao Copilot no repositorio confiavel para garantir a carga
  dos hooks e instrucoes. Testes por stdin validam o contrato, nao comprovam que
  uma sessao ja aberta recarregou os hooks. Timeouts podem ser fail-open no host.
- `core.hooksPath` e estado nao acompanham clones: rode install em cada clone.
  Nao desabilite hooks, edite seu estado ou as protecoes para contornar o fluxo.
