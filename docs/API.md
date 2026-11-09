# API — Teleprompter Meta

App nativo sem backend próprio. Este arquivo documenta os contratos internos (protocolos Swift entre as partes) e o contrato consumido do provedor de LLM. Mudança de contrato atualiza este arquivo e os testes no mesmo PR (ver [TESTING.md](TESTING.md)).

Status: aprovada em 2026-11-08

## 1. Visão
- Consumidores: o próprio app. Nenhuma API pública.
- Integrações externas: Meta DAT SDK (isolado em `Glasses`), STT, provedor de LLM (ADR-005, a decidir).
- Estilo: protocolos Swift com `AsyncStream` para fluxos em streaming.

## 2. Convenções
- Um protocolo por etapa do pipeline; implementação real e fake/simulada para cada.
- Fluxos contínuos (áudio, transcrição, tokens do LLM) usam `AsyncStream`; erros são tipados por parte.
- Nenhum tipo do DAT SDK sai do módulo `Glasses`.
- Datas em ISO 8601 UTC quando persistidas.

## 3. Erros
Erro tipado por parte (`AudioError`, `STTError`, `LLMError`, `GlassesError`). Mensagem para o usuário diz a causa e o próximo passo; log nunca contém o texto da fala.

## 4. Autenticação e autorização
- LLM: chave de API no Keychain, enviada só ao provedor escolhido (ADR-005). Sem papéis.

## 5. Versionamento e compatibilidade
- Contratos internos mudam livremente, com testes. Provedor de LLM e DAT SDK: fixar versão e revisar changelog antes de atualizar (SDK em developer preview).

## 6. Limites e desempenho
- Primeiro texto na lente em menos de 2 s (meta a validar). Lente 600x600 px: limite de linhas e fonte definido pelo `ResponseFormatter`.

## 7. Contratos

| Protocolo | Entrada e saída | Implementações | Teste |
|---|---|---|---|
| `AudioSource` | `AsyncStream<AudioBuffer>` | iPhone, HFP dos óculos, arquivo gravado | integração |
| `SpeechTranscriber` | áudio -> `AsyncStream<Transcript>` (parcial/final) | SpeechAnalyzer, alternativa (ADR-003) | integração |
| `QuestionDetector` | transcrição -> evento "pergunta completa" | puro | unitário |
| `Retriever` | pergunta -> trechos e nota de Q&A | índice local | unitário, integração |
| `AnswerGenerator` | pergunta + contexto -> `AsyncStream<String>` | `StreamingAnswerGenerator`, fake | integração com fake |
| `SecretStore` | get/set/delete por chave | `KeychainStore`, `InMemorySecretStore` | unitário, integração |
| `ResponseFormatter` | texto + formato -> conteúdo para a lente | puro | unitário, visual |
| `Lens` | exibe/limpa conteúdo; emite gestos | `SimulatedLens`, `GlassesLens` | E2E, manual |
| `Clock` | `now() -> ContinuousClock.Instant` | `SystemClock`, `TestClock` (fake) | unitário |

## 8. Contrato com o provedor de LLM (externo)

Endpoint compatível com chat completions (OpenAI format), consumido por `StreamingAnswerGenerator` via HTTPS POST com Server-Sent Events (SSE).

### 8.1. Requisição
- **Método / URL**: `POST <baseURL>/chat/completions` (ou `<baseURL>` se o caminho já terminar em `/completions`)
- **Headers**:
  - `Content-Type: application/json`
  - `Accept: text/event-stream`
  - `Authorization: Bearer <chave>` (lida de `SecretStore`, nunca incluída em URLs, corpos ou logs)
- **Corpo (JSON)**:
  ```json
  {
    "model": "<model>",
    "messages": [
      {
        "role": "system",
        "content": "Você é o assistente do Teleprompter. Responda exclusivamente com base nos trechos fornecidos no contexto..."
      },
      {
        "role": "user",
        "content": "Contexto:\nFonte: <caminho>\n<texto>\n\nPergunta:\n<pergunta>"
      }
    ],
    "stream": true
  }
  ```

### 8.2. Resposta
- **Content-Type**: `text/event-stream`
- **Formato dos eventos**:
  - Chunks em formato `data: {"choices":[{"delta":{"content":"..."}}]}`
  - Fim de transmissão indicado por `data: [DONE]`
- **RAG fechado**: se `context` estiver vazio, nenhuma requisição é disparada e o stream encerra imediatamente sem tokens.
- **Cancelamento**: o cancelamento da `Task` consumidora cancela a requisição ativa via `URLSession`.

### 8.3. Erros (`LLMError`)
- `.missingAPIKey`: chave não encontrada ou vazia no `SecretStore`.
- `.network(String)`: falha de transporte ou conexão HTTP (chave e pergunta sanitizadas).
- `.httpStatus(Int)`: status HTTP fora de 200...299 (ex.: 401, 500).
- `.invalidResponse`: payload SSE ou JSON que não segue a estrutura esperada.

## 9. Histórico de mudanças do contrato
- 2026-11-08: contrato `Clock` adicionado para medição determinística de latência e controle de silêncio (issue #36, US-01 a US-06, US-12, US-13).
- 2026-11-08: contrato com provedor de LLM (SSE chat completions) e `SecretStore` adicionados (US-04).
- 2026-11-08: contratos iniciais (rascunho).
