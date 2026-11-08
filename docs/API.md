# API — Teleprompter Meta

App nativo sem backend próprio. Este arquivo documenta os contratos internos (protocolos Swift entre as partes) e o contrato consumido do provedor de LLM. Mudança de contrato atualiza este arquivo e os testes no mesmo PR (ver [TESTING.md](TESTING.md)).

Status: rascunho

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
| `AnswerGenerator` | pergunta + contexto -> `AsyncStream<String>` | provedor de LLM, fake | integração com fake |
| `ResponseFormatter` | texto + formato -> conteúdo para a lente | puro | unitário, visual |
| `Lens` | exibe/limpa conteúdo; emite gestos | `SimulatedLens`, `GlassesLens` | E2E, manual |

## 8. Histórico de mudanças do contrato
- 2026-11-08: contratos iniciais (rascunho).
