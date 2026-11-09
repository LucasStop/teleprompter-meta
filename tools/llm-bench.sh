#!/usr/bin/env bash
# Benchmark de LLM (TTFT e qualidade) no iPhone físico, via LLMBenchmarkTests.
# As chaves vêm do ambiente de quem roda; o script nunca as imprime.
#
# Uso (no seu terminal):
#   OPENROUTER_API_KEY=... no .env da raiz ou exportado  # opcional: perfis via OpenRouter
#   export GROQ_API_KEY=...         # opcional: Groq direto
#   export ANTHROPIC_API_KEY=...    # opcional: Anthropic direto
#   export OPENAI_API_KEY=...       # opcional: OpenAI direto
#   tools/llm-bench.sh [UDID]
# Modelos sobrescrevíveis: OR_HAIKU_MODEL, OR_GEMINI_MODEL, OR_DEEPSEEK_MODEL, OR_NITRO_MODEL, OR_OPENAI_MODEL, GROQ_MODEL, ANTHROPIC_MODEL, OPENAI_MODEL.
# Confira os ids no catálogo de cada provedor antes de rodar.
set -euo pipefail

# Carrega o .env da raiz (ignorado pelo git) sem imprimir nada dele.
cd "$(dirname "$0")/.."
if [ -f .env ]; then set -a; . ./.env; set +a; fi

UDID="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /connected/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i}' | head -1)}"
TEAM="${DEVELOPMENT_TEAM:-69D4S5TF8S}"
[ -n "$UDID" ] || { echo "Nenhum iPhone físico conectado." >&2; exit 1; }

profiles="apple"
add() { # perfil, chave, url, modelo, formato
  local p="$1" n
  n=$(printf '%s' "$p" | tr '[:lower:]-' '[:upper:]_')
  export "TEST_RUNNER_LLM_${n}_KEY=$2" "TEST_RUNNER_LLM_${n}_BASE_URL=$3" \
    "TEST_RUNNER_LLM_${n}_MODEL=$4" "TEST_RUNNER_LLM_${n}_FORMAT=$5"
  profiles="$profiles,$p"
  echo "perfil $p: $4 ($3)"
}

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  add or-haiku "$OPENROUTER_API_KEY" https://openrouter.ai/api/v1 "${OR_HAIKU_MODEL:-anthropic/claude-haiku-5.5}" openai
  add or-gemini "$OPENROUTER_API_KEY" https://openrouter.ai/api/v1 "${OR_GEMINI_MODEL:-google/gemini-3.1-flash-lite}" openai
  add or-deepseek "$OPENROUTER_API_KEY" https://openrouter.ai/api/v1 "${OR_DEEPSEEK_MODEL:-deepseek/deepseek-v4-flash}" openai
  add or-nitro "$OPENROUTER_API_KEY" https://openrouter.ai/api/v1 "${OR_NITRO_MODEL:-deepseek/deepseek-v4-flash:nitro}" openai
  add or-openai "$OPENROUTER_API_KEY" https://openrouter.ai/api/v1 "${OR_OPENAI_MODEL:-openai/gpt-5-mini}" openai
fi
[ -n "${GROQ_API_KEY:-}" ] && add groq "$GROQ_API_KEY" https://api.groq.com/openai/v1 "${GROQ_MODEL:-llama-3.3-70b-versatile}" openai
[ -n "${ANTHROPIC_API_KEY:-}" ] && add anthropic "$ANTHROPIC_API_KEY" https://api.anthropic.com/v1 "${ANTHROPIC_MODEL:-claude-haiku-5-5}" anthropic
[ -n "${OPENAI_API_KEY:-}" ] && add openai "$OPENAI_API_KEY" https://api.openai.com/v1 "${OPENAI_MODEL:-gpt-5-mini}" openai

export TEST_RUNNER_RUN_LLM=1 TEST_RUNNER_LLM_PROVIDERS="$profiles"
echo "perfis: $profiles"

log="build.noindex/llm-bench-$(date +%Y%m%d-%H%M%S).log"
mkdir -p build.noindex
xcodebuild test -scheme Teleprompter -destination "id=$UDID" \
  -only-testing:TeleprompterTests/LLMBenchmarkTests \
  DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates > "$log" 2>&1 || true

# Só as tabelas e avisos do teste; nada de ambiente.
grep -E '^\||^###|\[AVISO\]|\[ERRO\]|error:|Test Case .*(passed|failed|skipped)' "$log" || tail -20 "$log"
echo "log completo: $log"
