# ADR 0004 — Busca local com caminho rápido pelo Q&A

- Status: proposta (decidir no gate G1, protótipo P3)
- Data: 2026-11-08

## Contexto
As melhores respostas são as que eu mesmo preparei, e cada chamada ao LLM custa tempo.

## Decisão
As notas de Q&A são consultadas primeiro; acima de um limiar de similaridade, a resposta sai direto. Abaixo dele, os trechos mais próximos de documentos e repositório vão ao LLM. A busca é híbrida: palavras-chave e embeddings.

## Alternativas consideradas
- Mandar tudo ao LLM: mais simples e mais lento.
- Só Q&A: sem cobertura para perguntas imprevistas.

## Consequências
- Positivas: perguntas previstas aparecem mais rápido e sem risco de invenção.
- Negativas e riscos: o limiar precisa ser calibrado no P3 e no ensaio.
- Impacto em testes e design: US-03 e US-04 testam os dois caminhos.
