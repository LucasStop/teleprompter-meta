# ADR 0007 — Protocolos com implementações simuladas

- Status: proposta (decidir no gate G2)
- Data: 2026-11-08

## Contexto
Os óculos ainda não foram comprados, e o Mock Device Kit não descreve simulação de display nem de microfone.

## Decisão
Cada etapa do pipeline é um protocolo, com implementações para iPhone, arquivo, simulação e óculos, escolhidas num único ponto de composição.

## Alternativas consideradas
- Esperar o hardware para começar.
- Usar só o Mock Device Kit, que não cobre o display.

## Consequências
- Positivas: as fases 0 a 2 e quase todos os testes rodam sem óculos.
- Negativas e riscos: uma camada a mais de abstração.
- Impacto em testes e design: `SimulatedLens` e `AudioSource` de arquivo; ver `docs/API.md`.
