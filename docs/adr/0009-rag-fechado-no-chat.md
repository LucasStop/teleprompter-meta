# ADR 0009 — RAG fechado no chat

- Status: proposta (decidir no gate G1, protótipo P3)
- Data: 2026-11-08

## Contexto
O app virou um chat (texto, microfone, escuta contínua). Na banca, resposta inventada é pior que resposta nenhuma.

## Decisão
O LLM só recebe trechos recuperados do material importado. Sem trecho acima do limiar de similaridade, o app responde "Não encontrei isso no seu material" e não chama o LLM. Toda resposta lista as fontes usadas.

Ajuste de 2026-11-09 (issue #90): o prompt do LLM manda responder com o que os trechos dizem, mesmo que parcialmente, e recusar com "Não encontrei isso no seu material" só quando nenhum trecho tiver relação. O benchmark mostrou o Haiku recusando perguntas cujo trecho estava no contexto com a regra anterior (recusar sempre que "não forem suficientes"). A regra de não usar conhecimento externo continua.

## Alternativas consideradas
- Resposta com conhecimento geral marcada como "fora do material": mais útil, menos confiável na banca.

## Consequências
- Positivas: sem invenção; fonte visível; menos chamadas ao LLM.
- Negativas e riscos: o limiar precisa ser calibrado no P3; pergunta mal formulada cai em "não encontrei".
- Impacto em testes e design: caso "sem trecho" nunca chama o LLM (TESTING); mensagem "não encontrei" no DESIGN.
