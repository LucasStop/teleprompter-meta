# Estratégia de testes — Teleprompter Meta

Decisão de quais testes valem para cada parte do projeto. Catálogo de tipos e matriz default: `~/.claude/TESTES.md`. Partes definidas em [ARCHITECTURE.md](ARCHITECTURE.md). Estratégia aprovada pelo Lucas antes da implementação.

Status: aprovada em 2026-11-08

## 1. Formato da suíte
- Formato: Troféu
- Por quê: app único sem backend. Unitários no núcleo (detector, formatador, busca), integração com áudios gravados e fakes dos protocolos como foco, E2E só na jornada crítica pela lente simulada.

## 2. Testes por parte

Preencher uma linha por parte listada em ARCHITECTURE.md. Tipos: estático, unitário, componente, integração, API, contrato, E2E, aceitação, visual, desempenho, segurança, acessibilidade, migração.

| Parte | Risco principal | Tipos aplicados | Ferramenta | Roda em | Fora de escopo e motivo |
|---|---|---|---|---|---|
| Audio e STT | Transcrição ruim a 8 kHz, perda de áudio | integração, desempenho | XCTest com as 30 perguntas gravadas (pt-BR) e fake de áudio; WER medido | local, PR | STT real nunca roda no PR; só no protótipo P1 |
| QuestionDetector | Corta a pergunta cedo ou dispara duas vezes | estático, unitário, aceitação | Swift Testing / XCTest (transcrições parciais sintéticas) | local, PR | Mutação só aqui (núcleo crítico) |
| Retrieval | Resposta errada ou nota não encontrada | unitário, integração, aceitação | XCTest com corpus fixo de Q&A, README e código de exemplo | PR | Qualidade semântica avaliada manualmente nos protótipos |
| LLM | Latência alta, contexto vazado, formato quebrado | integração com fake, contrato, desempenho | XCTest com fake de streaming; medição de primeiro token no protótipo P3 | PR | Chamada real ao provedor nunca roda no PR |
| ResponseFormatter | Texto estoura a lente 600x600 | unitário, visual | Swift Testing; swift-snapshot-testing | local, PR | |
| Glasses (DAT SDK) | Mudança do SDK em preview, queda de conexão | integração com Mock Device Kit, manual em campo | Mock Device Kit (não cobre display nem microfone); roteiro manual com óculos | PR (mock), manual (fases 3 a 5) | Teste automatizado com óculos reais não existe |
| Interface iPhone e lente simulada | Estado ou variante quebrada, jornada quebrada | componente, visual, acessibilidade, E2E | XCTest das ViewModels + previews; swift-snapshot-testing; XCUITest + performAccessibilityAudit | local, PR (smoke) | E2E só na jornada pergunta -> resposta |
| Persistência e segredos | Perda de configuração, chave no repo | integração, segurança | XCTest com fakes de arquivo; gitleaks + revisão de Keychain | PR | Migração só se adotar SwiftData |
| Infra / CI | Build quebrado | estático | GitHub Actions macOS, SwiftLint, gitleaks | PR | Sem deploy: instalação local no iPhone |

"Roda em": local (pré-commit ou sob demanda), PR (CI bloqueante), deploy (smoke pós-deploy), nightly (agendado).

## 3. Testes do projeto inteiro
- Estático: SwiftLint + compilador com warnings como erro + gitleaks, no `lefthook.yml` e no CI.
- Smoke: o app compila e o pipeline com fakes devolve uma resposta na lente simulada; primeiro job do CI.
- Regressão: a suíte completa roda em todo PR. Bug corrigido entra com teste que falha antes da correção, no mesmo PR.
- Aceitação: cada história do `PRD.md` tem ao menos um teste (ou checagem manual descrita) ligado ao critério de aceite. Mapa em [Rastreabilidade](#5-rastreabilidade).
- Exploratório: antes de cada gate, 30 min de sessão ensaiando perguntas ao vivo (charter: tentar quebrar detecção e formato).
- Não funcionais: desempenho (XCTest measure + Instruments; metas a validar: primeiro texto em menos de 2 s, WER abaixo de 15%, sessão de 60 min), segurança (gitleaks + revisão de entitlements e Keychain), acessibilidade (XCUITest performAccessibilityAudit + Accessibility Inspector), compatibilidade (iPhone físico em iOS 17.2+ e iOS 26).

## 4. Regras
- Cada teste no nível mais baixo que pega o defeito; sem repetir caso de borda entre níveis.
- Teste de regra de negócio nasce antes ou junto do código (TDD, `/tdd`).
- Dependência externa nunca é real nos testes automatizados de PR: usar fake, stub ou servidor de teste. Produção nunca.
- Dados de teste: fixtures (áudios das 30 perguntas e corpus de Q&A de exemplo), sem dado pessoal real.
- Flaky: corrigir ou quarentenar com issue em até 1 semana; nunca reexecutar até passar.
- Cobertura: gate de 80% sobre QuestionDetector, Retrieval e ResponseFormatter. Cobertura é alarme, não meta.
- Teste visual/E2E de tela referencia o protótipo aprovado em `design/telas.md`.

## 5. Rastreabilidade

| História (PRD) | Critério de aceite | Teste(s) | Nível |
|---|---|---|---|
| US-01 | WER abaixo de 15% | integração com áudios gravados | integração |
| US-02 | Fim detectado uma única vez | QuestionDetector | unitário |
| US-03 | Nota de Q&A devolvida sem LLM | Retrieval | unitário |
| US-04 | Primeiro texto em menos de 2 s, só contexto recuperado | LLM com fake; protótipo P3 | integração, manual |
| US-05 | Respeita limite da lente | ResponseFormatter | unitário, visual |
| US-06 | Lente simulada exibe a resposta | lente simulada | E2E, visual |
| US-07 | Configuração persiste | Persistência | integração |
| US-08 | Resposta na lente real | roteiro manual com óculos | manual |
| US-09 | Gesto repete ou pula | Glasses + manual | manual |
| US-10 | 60 min sem falha | sessão de campo | manual, desempenho |
| US-11 | Importação indexa o material | Retrieval | integração |

## 6. Comandos

```bash
xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 16'    # unitário + componente + integração
xcodebuild test -scheme TeleprompterUITests -destination 'platform=iOS Simulator,name=iPhone 16'     # E2E
swiftlint --strict    # estático
```

## 7. Pronto (Definition of Done) para PR
- [ ] Testes novos ou alterados cobrem a mudança no nível certo
- [ ] Suíte completa verde no CI
- [ ] Bug corrigido tem teste de regressão
- [ ] Tela nova ou alterada tem protótipo aprovado e teste (E2E/visual/a11y) conforme a tabela da seção 2
- [ ] Este arquivo atualizado se a estratégia mudou
