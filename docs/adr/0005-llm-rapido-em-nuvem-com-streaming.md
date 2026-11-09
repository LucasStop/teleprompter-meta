# ADR 0005 — LLM rápido em nuvem com streaming

- Status: aceita em 2026-11-09 (Lucas)
- Data: 2026-11-08

## Contexto
As respostas são curtas e o contexto é pequeno (os trechos recuperados), mas a latência até o primeiro token é crítica.

## Decisão
Um modelo pequeno e rápido de um provedor em nuvem, com streaming e cache do prompt fixo. Provedor: Anthropic Claude Haiku 5.5 (`anthropic/claude-haiku-5.5`) via OpenRouter, que é o padrão do app. O provedor é configurável em Ajustes (Apple, OpenRouter, Personalizado).

Medição de 2026-11-09 no iPhone 16 Pro, 30 perguntas sintéticas, TTFT:

| Perfil | p50 | p95 | Erros |
|---|---|---|---|
| Haiku 5.5 | 1434 ms | 1691 ms | 0 |
| DeepSeek v4 flash | 1034 ms | 2155 ms | 0 |
| DeepSeek v4 flash `:nitro` | 1275 ms | 2521 ms | 0 |
| Gemini 3.1 flash-lite, GPT-5 mini | n/a | n/a | HTTP 402 (conta sem saldo) |
| Apple Foundation Models | n/a | n/a | indisponível no aparelho |

Haiku tem o menor p95 e cumpre a meta de TTFT < 2 s; DeepSeek é mais rápido na mediana, mas passa de 2 s no p95. A rota `:nitro` não ajudou. Gemini e GPT-5 mini não foram medidos e ficam para quando houver saldo.

## Alternativas consideradas
- Modelo on-device do framework Foundation Models da Apple (iOS 26), sem rede, avaliado no P1 quanto à qualidade.
- Um modelo maior, mais completo e mais lento.

## Consequências
- Positivas: custo por chamada baixo para o volume de uma banca.
- Negativas e riscos: depende de rede; sem ela, o app responde só pelo Q&A direto. A pergunta transcrita sai do aparelho (registrar na privacidade).
- Impacto em testes e design: chamada real nunca roda no PR; fake de streaming.
