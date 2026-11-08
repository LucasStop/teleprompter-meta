# ADR 0002 — Orquestração no iPhone, sem servidor próprio

- Status: proposta (decidir no gate G1)
- Data: 2026-11-08

## Contexto
O app é pessoal, tem um único usuário e a prioridade é latência mínima.

## Decisão
O iPhone captura, transcreve, busca e chama o LLM diretamente, sem backend.

## Alternativas consideradas
- Servidor próprio (Laravel ou Node) intermediando o LLM: protege a chave, mas soma latência e manutenção.

## Consequências
- Positivas: um salto de rede a menos e nada para hospedar.
- Negativas e riscos: a chave da API fica no aparelho, no Keychain, aceitável para uso pessoal. Se o app virar produto, entra um servidor intermediário e um novo ADR.
- Impacto em testes e design: LLM atrás de protocolo com fake.
