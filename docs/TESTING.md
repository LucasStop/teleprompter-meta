# Estratégia de testes — Teleprompter Meta

Decisão de quais testes valem para cada parte do projeto. Catálogo de tipos e matriz default: `~/.claude/TESTES.md`. Partes definidas em [ARCHITECTURE.md](ARCHITECTURE.md). Estratégia aprovada pelo Lucas antes da implementação.

Status: aprovada em 2026-11-08 (revisão de 2026-11-08 aprovada)

## 1. Formato da suíte
- Formato: Troféu
- Por quê: app único sem backend. Unitários no núcleo (detector, formatador, busca), integração com áudios gravados e fakes dos protocolos como foco, fluxo de telas validado local com Maestro; XCUITest no CI só para smoke da jornada e acessibilidade.

## 2. Testes por parte

Preencher uma linha por parte listada em ARCHITECTURE.md. Tipos: estático, unitário, componente, integração, API, contrato, E2E, aceitação, visual, desempenho, segurança, acessibilidade, migração.

| Parte | Risco principal | Tipos aplicados | Ferramenta | Roda em | Fora de escopo e motivo |
|---|---|---|---|---|---|
| Audio e STT | Transcrição ruim a 8 kHz, perda de áudio, falha de asset de fala | unitário, integração, desempenho | XCTest com fakes de SpeechAssetManager (instalação, progresso, erro de download) e 30 perguntas gravadas (pt-BR); WER medido | local, PR | STT real e download de asset nunca rodam no PR; só no iPhone físico |
| Conversa (chat e RAG fechado) | Inventar resposta fora do material, perder fonte, misturar entradas | unitário, integração, aceitação | Swift Testing com fakes de Retriever e AnswerGenerator; caso "sem trecho acima do limiar" nunca chama o LLM | local, PR | Qualidade semântica manual nos protótipos |
| QuestionDetector | Corta a pergunta cedo ou dispara duas vezes | estático, unitário, aceitação | Swift Testing / XCTest (transcrições parciais sintéticas) | local, PR | Mutação só aqui (núcleo crítico) |
| Retrieval | Resposta errada ou nota não encontrada | unitário, integração, aceitação | XCTest com corpus fixo de Q&A, README e código de exemplo | PR | Qualidade semântica avaliada manualmente nos protótipos |
| LLM | Latência alta, contexto vazado, formato quebrado | integração com fake, contrato, desempenho | XCTest com fake de streaming; medição de primeiro token no protótipo P3 | PR | Chamada real ao provedor nunca roda no PR |
| ResponseFormatter | Texto estoura a lente 600x600 | unitário, visual | Swift Testing; swift-snapshot-testing | local, PR | |
| Glasses (DAT SDK) | Mudança do SDK em preview, queda de conexão | integração com Mock Device Kit, manual em campo | Mock Device Kit (não cobre display nem microfone); roteiro manual com óculos | PR (mock), manual (fases 3 a 5) | Teste automatizado com óculos reais não existe |
| Interface iPhone e lente simulada | Estado ou variante quebrada, jornada quebrada | componente, visual, acessibilidade, E2E | XCTest das ViewModels + previews; swift-snapshot-testing; Maestro (flows YAML, fluxo entre telas T01 a T07); XCUITest (smoke pergunta -> resposta + performAccessibilityAudit) | local (Maestro), PR (XCUITest) | Maestro não roda no CI (lento e instável em runner macOS); não cobre óculos nem microfone |
| Persistência e segredos | Perda de conversas ou configuração, chave no repo | integração, migração, segurança | XCTest com SQLite temporário (roundtrip, ordenação por mais recente, deleção, migração reversível user_version); InMemoryConversationStore; SettingsStoreTests, SettingsViewModelTests, KeychainTests (suites temporárias de UserDefaults e Keychain); gitleaks + revisão de Keychain | PR | - |
| Infra / CI | Build quebrado | estático | GitHub Actions macOS, SwiftLint, gitleaks | PR | Sem deploy: instalação local no iPhone |

"Roda em": local (pré-commit ou sob demanda), PR (CI bloqueante), deploy (smoke pós-deploy), nightly (agendado).

## 3. Testes do projeto inteiro
- Estático: SwiftLint + compilador com warnings como erro + gitleaks (`gitleaks detect --source . --redact --no-banner --config .gitleaks.toml`), no `lefthook.yml` e no job `gitleaks` do CI.
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
- Cobertura: gate de 80% ponderado por grupo sobre QuestionDetector (`QuestionDetector`, `PauseQuestionDetector`), Retrieval (`Retrieval/*`) e ResponseFormatter (`ResponseFormatter`, `LensFormatter`), verificado via `tools/coverage-gate.sh`. Cobertura é alarme, não meta.
- Teste visual/E2E de tela referencia o protótipo aprovado em `design/telas.md`.

## 5. Rastreabilidade

| História (PRD) | Critério de aceite | Teste(s) | Nível |
|---|---|---|---|
| US-01 | WER abaixo de 15% | integração com áudios gravados | integração |
| US-02 | Fim detectado uma única vez | QuestionDetector | unitário |
| US-03 | Nota de Q&A devolvida sem LLM | Retrieval | unitário |
| US-04 | Primeiro texto em menos de 2 s, só contexto recuperado | LLM com fake; protótipo P3 | integração, manual |
| US-05 | Respeita limite da lente e formato configurado | ResponseFormatter, SettingsViewModelTests | unitário, visual |
| US-06 | Lente simulada exibe a resposta | lente simulada | E2E, visual |
| US-07 | Configuração persiste | SettingsStoreTests, SettingsViewModelTests | integração, unitário |
| US-08 | Resposta na lente real | roteiro manual com óculos | manual |
| US-09 | Gesto repete ou pula | Glasses + manual | manual |
| US-10 | 60 min sem falha | sessão de campo | manual, desempenho |
| US-11 | Importação indexa o material | MaterialChunker, MaterialImporter, MaterialViewModel, MaterialIntegration | unitário, integração, aceitação |
| US-12 | Entrada por texto e áudio recebem resposta pelo mesmo pipeline | ConversationViewModel, ConversationAudio, AppEnvironmentIntegrationTests | unitário, integração |
| US-13 | Sem trecho acima do limiar responde "Não encontrei" sem chamar LLM | ConversationViewModel, AppEnvironmentIntegrationTests | unitário, aceitação, integração |
| US-14 | Conversas salvas no aparelho, abrir e apagar por mais recente | ConversationStoreTests, ConversationsViewModelTests, AppEnvironmentIntegrationTests | unitário, integração, componente |
| US-01 a US-05 (T05) | Ensaio com perguntas gravadas, resposta, latência por etapa e WER | EnsaioRunnerTests, EnsaioViewModelTests | unitário, integração |

## 6. Comandos

```bash
xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17'    # unitário + componente + integração
xcodebuild test -scheme TeleprompterUITests -destination 'platform=iOS Simulator,name=iPhone 17'     # XCUITest: smoke e acessibilidade (CI)
maestro test .maestro/    # fluxo de telas contra os protótipos aprovados (local, antes de cada gate)
swiftlint --strict    # estático

# Detecção de segredos (gitleaks):
gitleaks detect --source . --redact --no-banner --config .gitleaks.toml

# Testes com cobertura e validação do gate (80% no núcleo: detector, retrieval, formatter):
xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -enableCodeCoverage YES -resultBundlePath build.noindex/Test.xcresult -derivedDataPath build.noindex
./tools/coverage-gate.sh build.noindex/Test.xcresult
# Ajuste do limiar mínimo (padrão 80%): COVERAGE_MIN=85 ./tools/coverage-gate.sh build.noindex/Test.xcresult

# Harness de WER (STT real sobre perguntas gravadas):
RUN_STT=1 xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TeleprompterTests/WERHarnessTests

# Geração de áudios sintéticos das perguntas (ElevenLabs):
ELEVENLABS_API_KEY="..." ./tools/gerar-audios.sh --listar-vozes
ELEVENLABS_API_KEY="..." ELEVENLABS_VOICE_A="<id-voz-a>" ELEVENLABS_VOICE_B="<id-voz-b>" ./tools/gerar-audios.sh
./tools/gerar-audios.sh --ruido    # gera ruido-voz-a a partir de voz-a sem chamada de rede

# Benchmark de recuperação (só roda com RUN_BENCH=1):
TEST_RUNNER_RUN_BENCH=1 RUN_BENCH=1 xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TeleprompterTests/RetrievalBenchmarkTests

# Benchmark de provedores de LLM (só roda com RUN_LLM=1):
TEST_RUNNER_RUN_LLM=1 RUN_LLM=1 xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TeleprompterTests/LLMBenchmarkTests
```

### Gravação, geração e execução do harness de WER
- Local dos arquivos: `TeleprompterTests/Fixtures/perguntas/`.
- Formato do áudio: 8 kHz mono PCM 16 bits (LEI16@8000).
- Estrutura de conjuntos (subpastas com arquivos `.wav`):
  - `voz-a/`: áudios sintetizados via ElevenLabs com a voz A (ID em `$ELEVENLABS_VOICE_A`, modelo multilíngue pt-BR), pareados com `../NN.txt`.
  - `voz-b/`: áudios sintetizados via ElevenLabs com a voz B (ID em `$ELEVENLABS_VOICE_B`), pareados com `../NN.txt`.
  - `ruido-voz-a/`: segunda passada gerada via `ffmpeg` a partir de `voz-a` (sem chamada de rede), aplicando ruído branco leve e filtro passa-banda de 300 a 3400 Hz (simulação de canal telefônico / compressão de áudio bluetooth HFP).
  - `humano/`: áudios autênticos gravados pelo Lucas (as 30 perguntas da banca), aceitando transcrições locais `humano/NN.txt` ou caindo para `../NN.txt`.
- Pareamento de arquivos: o harness descobre os conjuntos automaticamente pelas subpastas de `Fixtures/perguntas/` que contenham `.wav`, buscando a transcrição de referência primeiro localmente na subpasta (`<conjunto>/NN.txt`) e, se ausente, na pasta raiz (`Fixtures/perguntas/NN.txt`). Arquivos sem referência correspondente são ignorados.
- O que o WER sintético prova e não prova:
  - *O que prova*: valida o pipeline de transcrição on-device de ponta a ponta (decodificação de buffer PCM a 8 kHz, entrega contínua para o `SpeechAnalyzer`, robustez lexical com vocabulário técnico de Engenharia de Software em português do Brasil e comportamento sob ruído de banda estreita).
  - *O que não prova*: não substitui a acústica real da fala humana (prosódia, respiração, variações espontâneas de entonação e microfone HFP físico com ruído de sala de aula). Por isso, a asserção do limite de 15% de WER (PRD US-01) aplica-se exclusivamente ao conjunto `humano`. Os conjuntos sintéticos apenas reportam a média e a pior pergunta no log do teste.
- Execução do teste:
  - O teste completo com STT (`WERHarnessTests.testWordErrorRateOnRecordedQuestions`) roda apenas localmente com `RUN_STT=1` (faz `XCTSkip` no CI e quando não houver `.wav`).
  - Os testes unitários de pareamento de arquivos e métricas (`WERDatasetDiscoveryTests` e similares dentro de `WERHarnessTests`) rodam sempre na suíte padrão sem depender de STT nem de chamada de rede.

## 7. Pronto (Definition of Done) para PR
- [ ] Testes novos ou alterados cobrem a mudança no nível certo
- [ ] Suíte completa verde no CI
- [ ] Bug corrigido tem teste de regressão
- [ ] Tela nova ou alterada tem protótipo aprovado e teste (E2E/visual/a11y) conforme a tabela da seção 2
- [ ] Este arquivo atualizado se a estratégia mudou

## 8. Estado atual da suíte

Medição executada localmente no simulador iPhone 17 (iOS 17.2+, Xcode 27.2 / macOS Apple Silicon):

### 8.1. Contagem de testes
- Total de testes executados: 186
- Falhas: 0
- Testes com skip documentado (`XCTSkip`): 3
  - `WERHarnessTests.testWordErrorRateOnRecordedQuestions` (requer `RUN_STT=1` e gravações humanas)
  - `RetrievalBenchmarkTests.testRetrievalAndPipelineBenchmark` (requer `RUN_BENCH=1`)
  - `LLMBenchmarkTests.testBenchmarkCandidatesIfConfigured` (requer `RUN_LLM=1`)
- Tempo de execução dos testes: 1.470 s

### 8.2. Gates de CI (automatizados e bloqueantes)
- SwiftLint (`swiftlint --strict`): 0 violações em 104 arquivos Swift.
- Detecção de segredos (`gitleaks detect --source . --redact --no-banner --config .gitleaks.toml`): 0 vazamentos encontrados (40 commits escaneados).
- Execução de testes (`xcodebuild test`): 186 testes executados com 100% de sucesso.
- Gate de cobertura do núcleo (`./tools/coverage-gate.sh` com limiar mínimo de 80.0%):
  - detector: 96.15% (25/26 linhas) [APROVADO]
  - retrieval: 84.58% (576/681 linhas) [APROVADO]
  - formatter: 97.10% (67/69 linhas) [APROVADO]

### 8.3. O que continua manual
- Medição empírica de WER no iPhone físico com o asset offline de língua portuguesa do SpeechAnalyzer baixado e as 30 perguntas gravadas com fala humana autêntica do Lucas (`humano/NN.wav`).
- Hardware dos óculos (Meta Ray-Ban Display via Meta DAT SDK): pareamento, canal de microfone Bluetooth HFP a 8 kHz e renderização no display óptico (fase 3).
- Gestos no Meta Neural Band para repetir ou descartar a resposta (fase 4).
- Teste de resistência e estabilidade por 60 min de sessão contínua (fase 5).
- Avaliação de latência TTFT (tempo até o primeiro token < 2 s) com chamada real de rede ao provedor de LLM definido no ADR-0005.
