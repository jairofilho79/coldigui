#!/bin/bash
# sessionStart — injeta contexto do projeto PLPCG e reseta budget de loops.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=loop-budget.sh
source "$SCRIPT_DIR/loop-budget.sh"

echo "0" > "$LOOP_STATE_FILE"

jq -n '{
  "additional_context": "Projeto PLPCG Flutter (coldigui). Spec: MAPEAMENTO_PLPCG_FLUTTER.md. UCs em docs/use-cases/. Ordem MVP: core → catalog → library → pdf_opening → pdf_reader → offline. ADR-001 Isar, ADR-002 PDFx. UC-13 fora do MVP. Pipeline de agentes em .cursor/skills/agents/. Limite 5 loops/sessão."
}'

exit 0
