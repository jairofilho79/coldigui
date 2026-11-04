# Entrega de tarefas

Para toda tarefa que modifica este repositorio, carregue e siga
[task-delivery](skills/task-delivery/SKILL.md).

- Preserve o gate de entendimento, DoR/DoD e aprovacao antes de implementar.
- Depois da aprovacao, crie e registre uma branch `feature/<slug>` ou `fix/<slug>`
  antes da primeira alteracao. Nunca implemente ou comite diretamente na `main`.
- Ao concluir e validar a tarefa, prepare a versao uma unica vez e crie um PR
  contendo somente as alteracoes da tarefa. Nao encerre como entregue sem PR;
  se houver impedimento, declare explicitamente o bloqueio.
- Merge exige aprovacao explicita do usuario para o PR e seu HEAD atual.
  Aprovacao do plano nao autoriza merge nem deploy.
- Apos o merge, ofereca deploy completo, skips de web/android/ios ou nenhum
  deploy. Aguarde uma autorizacao separada antes de executar.
- Consultas sem alteracoes nao criam branch, incremento ou PR. Fim de turno,
  perguntas e espera por aprovacao nao significam conclusao da tarefa.
