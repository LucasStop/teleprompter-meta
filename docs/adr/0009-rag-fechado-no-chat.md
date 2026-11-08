# ADR 0009 — RAG fechado no chat

- Status: proposta (decidir no gate G1, protótipo P3)
- Data: 2026-11-08

## Contexto
O app virou um chat (texto, microfone, escuta contínua). Na banca, resposta inventada é pior que resposta nenhuma.

## Decisão
O LLM só recebe trechos recuperados do material importado. Sem trecho acima do limiar de similaridade, o app responde "Não encontrei isso no seu material" e não chama o LLM. Toda resposta lista as fontes usadas.

## Alternativas consideradas
- Resposta com conhecimento geral marcada como "fora do material": mais útil, menos confiável na banca.

## Consequências
- Positivas: sem invenção; fonte visível; menos chamadas ao LLM.
- Negativas e riscos: o limiar precisa ser calibrado no P3; pergunta mal formulada cai em "não encontrei".
- Impacto em testes e design: caso "sem trecho" nunca chama o LLM (TESTING); mensagem "não encontrei" no DESIGN.
