#!/usr/bin/env bash
# tools/gerar-audios.sh
# Gera áudios de teste (8 kHz mono PCM 16-bit) para o harness de WER usando a API ElevenLabs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/TeleprompterTests/Fixtures/perguntas"

FORCAR=0
LISTAR_VOZES=0
GERAR_RUIDO=0

mostrar_ajuda() {
    cat << 'EOF'
Uso: tools/gerar-audios.sh [opções]

Gera os arquivos NN.wav das perguntas em 8 kHz mono PCM 16 bits para avaliação de WER.

Opções:
  --listar-vozes   Lista IDs e nomes das vozes da conta (filtradas por pt-BR)
  --forcar         Regera os áudios mesmo se os arquivos já existirem
  --ruido          Gera segunda passada 'ruido-voz-a' com ruído e banda 300-3400 Hz (ffmpeg)
  -h, --help       Mostra esta mensagem de ajuda

Variáveis de ambiente:
  ELEVENLABS_API_KEY  Chave de API da ElevenLabs (obrigatória para síntese e listagem)
  ELEVENLABS_VOICE_A  ID da voz A para o conjunto voz-a
  ELEVENLABS_VOICE_B  ID da voz B para o conjunto voz-b
  ELEVENLABS_MODEL    Modelo multilíngue (padrão: eleven_multilingual_v2)
EOF
}

# Processamento de argumentos
while [ $# -gt 0 ]; do
    case "$1" in
        --listar-vozes)
            LISTAR_VOZES=1
            shift
            ;;
        --forcar)
            FORCAR=1
            shift
            ;;
        --ruido)
            GERAR_RUIDO=1
            shift
            ;;
        -h|--help)
            mostrar_ajuda
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1" >&2
            mostrar_ajuda >&2
            exit 1
            ;;
    esac
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tratar_erro_http() {
    local code="$1"
    local body_file="$2"
    local context="$3"

    case "$code" in
        401)
            echo "Erro 401 (Não autorizado) ao $context:" >&2
            echo "  A chave ELEVENLABS_API_KEY é inválida ou expirou." >&2
            echo "  Verifique sua chave no console da ElevenLabs." >&2
            ;;
        402)
            echo "Erro 402 (Pagamento necessário) ao $context:" >&2
            if command -v jq >/dev/null 2>&1 && [ -f "$body_file" ]; then
                jq -r '.detail.message // empty' "$body_file" 2>/dev/null | sed 's/^/  /' >&2 || true
            fi
            echo "  Causas comuns: sem créditos de caracteres ou voz da biblioteca no plano Free." >&2
            echo "  Cota: https://elevenlabs.io/app/usage" >&2
            ;;
        429)
            echo "Erro 429 (Limite de requisições excedido) ao $context:" >&2
            echo "  Muitas requisições em curto intervalo. Aguarde alguns instantes antes de tentar novamente." >&2
            ;;
        *)
            local detail=""
            if command -v jq >/dev/null 2>&1 && [ -f "$body_file" ]; then
                detail=$(jq -r '.detail.message // .detail // empty' "$body_file" 2>/dev/null || true)
            fi
            echo "Erro HTTP $code ao $context." >&2
            if [ -n "$detail" ]; then
                echo "  Detalhe retornado pela API: $detail" >&2
            fi
            ;;
    esac
}

listar_vozes() {
    if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
        echo "Erro: variável de ambiente ELEVENLABS_API_KEY não configurada." >&2
        echo "Defina a chave antes de listar vozes: export ELEVENLABS_API_KEY=\"sua_chave\"" >&2
        exit 1
    fi

    local resp_file="$TMP_DIR/voices.json"
    local http_code
    http_code=$(curl -s -S -o "$resp_file" -w "%{http_code}" \
        -X GET "https://api.elevenlabs.io/v1/voices" \
        -H "xi-api-key: ${ELEVENLABS_API_KEY}")

    if [ "$http_code" -ne 200 ]; then
        tratar_erro_http "$http_code" "$resp_file" "listar vozes"
        exit 1
    fi

    echo "Vozes encontradas na conta ElevenLabs:"
    echo "================================================================================"
    printf "%-26s  %-28s  %s\n" "ID DA VOZ" "NOME" "DETALHES"
    echo "================================================================================"

    local encontrou=0
    if command -v jq >/dev/null 2>&1; then
        while IFS=$'\t' read -r vid vname vdet; do
            if [ -n "$vid" ]; then
                printf "%-26s  %-28s  %s\n" "$vid" "$vname" "$vdet"
                encontrou=1
            fi
        done < <(jq -r '.voices[] | select(
            (.labels.accent? // "" | ascii_downcase | test("portuguese|brazil|brasil")) or
            (.labels.language? // "" | ascii_downcase | test("pt|portuguese")) or
            ((.verified_languages? // []) | any(.language? == "pt" or (.locale? // "" | test("pt"))))
        ) | [ .voice_id, .name, (.labels.accent // .labels.gender // "pt-BR") ] | @tsv' "$resp_file" 2>/dev/null || true)

        if [ "$encontrou" -eq 0 ]; then
            echo "(Nenhuma voz com rótulo explícito pt-BR encontrado. Listando todas as vozes:)"
            jq -r '.voices[] | [ .voice_id, .name, (.labels.accent // .labels.gender // "-") ] | @tsv' "$resp_file" | while IFS=$'\t' read -r vid vname vdet; do
                printf "%-26s  %-28s  %s\n" "$vid" "$vname" "$vdet"
            done
        fi
    else
        grep -o '"voice_id":"[^"]*"' "$resp_file" | cut -d'"' -f4
    fi
    echo "================================================================================"
}

converter_para_wav_8khz() {
    local src="$1"
    local dst="$2"

    if command -v afconvert >/dev/null 2>&1; then
        afconvert -f WAVE -d LEI16@8000 -c 1 "$src" "$dst"
    elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -v error -i "$src" -ar 8000 -ac 1 -c:a pcm_s16le "$dst"
    else
        echo "Erro: nem afconvert nem ffmpeg foram encontrados para conversão de áudio." >&2
        return 1
    fi
}

sintetizar_conjunto() {
    local conjunto="$1"
    local voice_id="$2"
    local model_id="$3"
    local target_dir="$FIXTURES_DIR/$conjunto"

    mkdir -p "$target_dir"
    echo "Sintetizando conjunto [$conjunto] (voz: $voice_id, modelo: $model_id)..."

    local txt_files=("$FIXTURES_DIR"/[0-9][0-9].txt)
    if [ ! -e "${txt_files[0]}" ]; then
        echo "Erro: nenhum arquivo de pergunta NN.txt encontrado em $FIXTURES_DIR." >&2
        exit 1
    fi

    for txt_file in "${txt_files[@]}"; do
        [ -f "$txt_file" ] || continue
        local num
        num=$(basename "$txt_file" .txt)
        local wav_file="$target_dir/${num}.wav"

        if [ -f "$wav_file" ] && [ "$FORCAR" -eq 0 ]; then
            echo "  [$conjunto] ${num}.wav já existe, pulando (--forcar para refazer)"
            continue
        fi

        local texto
        texto=$(tr '\n' ' ' < "$txt_file" | sed 's/[[:space:]]\+/ /g' | sed 's/^ //;s/ $//')

        local payload
        if command -v jq >/dev/null 2>&1; then
            payload=$(jq -n --arg t "$texto" --arg m "$model_id" '{text: $t, model_id: $m}')
        else
            local escaped_t
            escaped_t=$(printf '%s' "$texto" | sed 's/\\/\\\\/g; s/"/\\"/g')
            payload="{\"text\":\"$escaped_t\",\"model_id\":\"$model_id\"}"
        fi

        local temp_mp3="$TMP_DIR/${conjunto}_${num}.mp3"
        local http_code
        http_code=$(curl -s -S -o "$temp_mp3" -w "%{http_code}" \
            -X POST "https://api.elevenlabs.io/v1/text-to-speech/${voice_id}?output_format=mp3_44100_128" \
            -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$payload")

        if [ "$http_code" -ne 200 ]; then
            tratar_erro_http "$http_code" "$temp_mp3" "gerar ${conjunto}/${num}.wav"
            rm -f "$temp_mp3"
            exit 1
        fi

        converter_para_wav_8khz "$temp_mp3" "$wav_file"
        rm -f "$temp_mp3"
        echo "  [$conjunto] Gerado ${num}.wav com sucesso"
    done
}

gerar_conjunto_ruido() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Erro: ffmpeg é necessário para gerar o conjunto com ruído (--ruido)." >&2
        exit 1
    fi

    local src_dir="$FIXTURES_DIR/voz-a"
    local dst_dir="$FIXTURES_DIR/ruido-voz-a"
    mkdir -p "$dst_dir"

    local src_files=("$src_dir"/[0-9][0-9].wav)
    if [ ! -e "${src_files[0]}" ]; then
        echo "Erro: nenhum arquivo .wav encontrado em $src_dir para gerar ruido-voz-a." >&2
        echo "Gere o conjunto voz-a antes de rodar com --ruido." >&2
        exit 1
    fi

    echo "Gerando conjunto [ruido-voz-a] com ruído branco leve e banda 300-3400 Hz..."
    for src_wav in "${src_files[@]}"; do
        [ -f "$src_wav" ] || continue
        local fname
        fname=$(basename "$src_wav")
        local dst_wav="$dst_dir/$fname"

        if [ -f "$dst_wav" ] && [ "$FORCAR" -eq 0 ]; then
            echo "  [ruido-voz-a] $fname já existe, pulando (--forcar para refazer)"
            continue
        fi

        ffmpeg -y -v error -i "$src_wav" \
            -filter_complex "anoisesrc=d=60:c=white:a=0.015:r=8000[noise];[0:a][noise]amix=inputs=2:duration=first:dropout_transition=0,highpass=f=300,lowpass=f=3400" \
            -ar 8000 -ac 1 -c:a pcm_s16le "$dst_wav"
        echo "  [ruido-voz-a] Gerado $fname com sucesso"
    done
}

# Modo de listagem de vozes
if [ "$LISTAR_VOZES" -eq 1 ]; then
    listar_vozes
    exit 0
fi

# Se foi solicitado apenas ruído e já temos voz-a e a chave não foi informada
if [ "$GERAR_RUIDO" -eq 1 ] && [ -z "${ELEVENLABS_API_KEY:-}" ]; then
    gerar_conjunto_ruido
    exit 0
fi

# Validação da chave da API
if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
    echo "Erro: variável de ambiente ELEVENLABS_API_KEY não configurada." >&2
    echo "Defina a chave antes de executar: export ELEVENLABS_API_KEY=\"sua_chave\"" >&2
    exit 1
fi

# Validação das vozes
if [ -z "${ELEVENLABS_VOICE_A:-}" ]; then
    echo "Erro: variável ELEVENLABS_VOICE_A não configurada." >&2
    echo "Defina o ID da voz A: export ELEVENLABS_VOICE_A=\"id_da_voz\"" >&2
    echo "Dica: use '$0 --listar-vozes' para consultar as vozes disponíveis." >&2
    exit 1
fi

if [ -z "${ELEVENLABS_VOICE_B:-}" ]; then
    echo "Erro: variável ELEVENLABS_VOICE_B não configurada." >&2
    echo "Defina o ID da voz B: export ELEVENLABS_VOICE_B=\"id_da_voz\"" >&2
    echo "Dica: use '$0 --listar-vozes' para consultar as vozes disponíveis." >&2
    exit 1
fi

MODELO="${ELEVENLABS_MODEL:-eleven_multilingual_v2}"

# Síntese das vozes sintéticas
sintetizar_conjunto "voz-a" "$ELEVENLABS_VOICE_A" "$MODELO"
sintetizar_conjunto "voz-b" "$ELEVENLABS_VOICE_B" "$MODELO"

# Segunda passada opcional com ruído
if [ "$GERAR_RUIDO" -eq 1 ]; then
    gerar_conjunto_ruido
fi

echo "Concluído com sucesso."
