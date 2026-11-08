# ADR 0005 — LLM rápido em nuvem com streaming

- Status: proposta (decidir no gate G1, protótipo P1)
- Data: 2026-11-08

## Contexto
As respostas são curtas e o contexto é pequeno (os trechos recuperados), mas a latência até o primeiro token é crítica.

## Decisão
Um modelo pequeno e rápido de um provedor em nuvem, com streaming e cache do prompt fixo. O provedor sai das medições do P1 (questão em aberto).

## Alternativas consideradas
- Modelo on-device do framework Foundation Models da Apple (iOS 26), sem rede, avaliado no P1 quanto à qualidade.
- Um modelo maior, mais completo e mais lento.

## Consequências
- Positivas: custo por chamada baixo para o volume de uma banca.
- Negativas e riscos: depende de rede; sem ela, o app responde só pelo Q&A direto. A pergunta transcrita sai do aparelho (registrar na privacidade).
- Impacto em testes e design: chamada real nunca roda no PR; fake de streaming.
