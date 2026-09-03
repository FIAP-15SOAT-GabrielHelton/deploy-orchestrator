#!/usr/bin/env bash
# Dispara um workflow_dispatch em outro repositório (via PAT, já que o
# GITHUB_TOKEN padrão não pode disparar workflows fora deste repo) e aguarda
# sua conclusão, falhando (exit != 0) se a run não terminar com sucesso.
#
# Uso: run_and_wait.sh <repo> <workflow-file> <aws_access_key_id> <aws_secret_access_key> <aws_session_token>
set -euo pipefail

REPO_NAME="$1"
WORKFLOW_FILE="$2"
AWS_ACCESS_KEY_ID="$3"
AWS_SECRET_ACCESS_KEY="$4"
AWS_SESSION_TOKEN="$5"

FULL_REPO="${ORG}/${REPO_NAME}"

echo "Disparando ${WORKFLOW_FILE} em ${FULL_REPO}..."
DISPATCHED_AT=$(date -u +%Y-%m-%dT%H:%M:%S)

gh workflow run "$WORKFLOW_FILE" \
  --repo "$FULL_REPO" \
  -f aws_access_key_id="$AWS_ACCESS_KEY_ID" \
  -f aws_secret_access_key="$AWS_SECRET_ACCESS_KEY" \
  -f aws_session_token="$AWS_SESSION_TOKEN"

# `gh workflow run` não retorna o run id diretamente — precisamos localizar a
# run que acabamos de criar entre as mais recentes (criada após o dispatch).
RUN_ID=""
for _ in $(seq 1 15); do
  sleep 4
  RUN_ID=$(gh run list \
    --repo "$FULL_REPO" \
    --workflow "$WORKFLOW_FILE" \
    --limit 5 \
    --json databaseId,createdAt \
    --jq "[.[] | select(.createdAt >= \"${DISPATCHED_AT}\")] | sort_by(.createdAt) | .[0].databaseId // empty")

  if [ -n "$RUN_ID" ]; then
    break
  fi
  echo "Aguardando a run aparecer em ${FULL_REPO}..."
done

if [ -z "$RUN_ID" ]; then
  echo "::error::Não foi possível localizar a run disparada em ${FULL_REPO}/${WORKFLOW_FILE}."
  exit 1
fi

echo "Aguardando conclusão da run ${RUN_ID} em ${FULL_REPO}..."
gh run watch "$RUN_ID" --repo "$FULL_REPO" --exit-status
