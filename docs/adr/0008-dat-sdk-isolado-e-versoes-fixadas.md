# ADR 0008 — DAT SDK isolado num módulo e versões fixadas

- Status: proposta (decidir no gate G2)
- Data: 2026-11-08

## Contexto
O SDK está em developer preview, e as APIs podem mudar entre versões.

## Decisão
Todo código que importa o SDK fica no módulo `Glasses`. A versão do pacote fica fixada no `Package.resolved`, e o app Meta AI e o firmware não são atualizados nas semanas antes da banca.

## Alternativas consideradas
- Usar o SDK direto nas views e nos view models: menos código, mais acoplamento.

## Consequências
- Positivas: uma mudança do SDK quebra um só módulo; atualizar vira decisão explícita, registrada num novo ADR.
- Negativas e riscos: `Package.resolved` precisa ser versionado (não é lockfile JS, a regra do yarn não se aplica).
- Impacto em testes e design: nenhum tipo do SDK nos demais módulos.
