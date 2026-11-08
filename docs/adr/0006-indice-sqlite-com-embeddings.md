# ADR 0006 — Índice em SQLite com embeddings no aparelho

- Status: proposta (decidir no gate G1, protótipo P3)
- Data: 2026-11-08

## Contexto
O material cabe em poucos milhares de trechos, e a busca precisa funcionar sem rede.

## Decisão
O indexador (`Tools/Indexer`) gera um arquivo SQLite com FTS5 para palavras-chave e uma tabela de embeddings. Os embeddings usam o mesmo modelo no indexador e no app, como o `NLContextualEmbedding` da Apple ou um modelo Core ML pequeno.

## Alternativas consideradas
- Embeddings por API: melhor qualidade, mas uma chamada de rede a mais por pergunta.
- SwiftData: sem busca textual pronta.

## Consequências
- Positivas: sem banco vetorial nem servidor; com esse volume, busca vetorial por força bruta basta.
- Negativas e riscos: trocar o modelo de embeddings exige reindexar.
- Impacto em testes e design: corpus fixo de teste; `docs/DATA.md` reflete o SQLite.
