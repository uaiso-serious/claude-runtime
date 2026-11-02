#!/bin/bash
# CMD padrão: inicia o Claude Code. O contexto (repo, CLI, issue) vai para ~/.claude/rules/runtime-context.md (não mexe no CLAUDE.md do toolbox).
#   ISSUE_PROMPT    prompt inicial (padrão: resolver a issue, só no AUTONOMOUS_MODE com ISSUE_ID; no interativo abre sem prompt)
#   ISSUE_COMMENTS  true = inclui /tmp/issue/comments.md no contexto
#   MODEL           modelo do claude (--model), quando definido
#   AUTONOMOUS_MODE true = roda sem interação (claude -p)
set -euo pipefail

ISSUE_PROMPT="${ISSUE_PROMPT:-}"
if [[ -z "$ISSUE_PROMPT" && -n "${ISSUE_ID:-}" && "${AUTONOMOUS_MODE:-false}" == "true" ]]; then
  ISSUE_PROMPT="Resolva a issue #${ISSUE_ID}."
fi

mkdir -p "$HOME/.claude/rules"
context=(/tmp/repo/repo.md /tmp/repo/cli.md)
if [[ -n "${ISSUE_ID:-}" ]]; then
  context+=(/tmp/issue/issue.md)
  [[ "${ISSUE_COMMENTS:-false}" == "true" ]] && context+=(/tmp/issue/comments.md)
fi
for f in "${context[@]}"; do
  [[ -f "$f" ]] && { cat "$f"; echo; }
done > "$HOME/.claude/rules/runtime-context.md"

# tags do trace no Langfuse (plugin langfuse-observability): filtro de custo por issue, author e coauthor
co_author="${GIT_CO_AUTHOR:-}"
co_author="${co_author##*<}"
co_author="${co_author%%>*}"
mode=interactive
[[ "${AUTONOMOUS_MODE:-false}" == "true" ]] && mode=autonomous
export CC_LANGFUSE_TRACE_TAGS="mode:${mode}"
# user_id do trace: LANGFUSE_USER_ID já definido > e-mail do co-autor > GIT_USER_EMAIL
export LANGFUSE_USER_ID="${LANGFUSE_USER_ID:-${co_author:-${GIT_USER_EMAIL:-}}}"

args=()
[[ -n "${MODEL:-}" ]] && args+=(--model "$MODEL")
if [[ "${AUTONOMOUS_MODE:-false}" == "true" ]]; then
  [[ -n "$ISSUE_PROMPT" ]] || { echo "AUTONOMOUS_MODE=true exige ISSUE_ID ou ISSUE_PROMPT" >&2; exit 1; }
  exec claude "${args[@]}" -p "$ISSUE_PROMPT" --dangerously-skip-permissions
fi
exec claude "${args[@]}" ${ISSUE_PROMPT:+"$ISSUE_PROMPT"}
