# Tarefa: sincronizar docs com o app implementado (issue #66)

Objetivo: docs vivos refletem o que existe hoje em main. Só edita Markdown em docs/ e README.md; nenhuma linha de código.
Leia o código e os testes reais antes de escrever (Teleprompter/, TeleprompterTests/, .github/workflows/ci.yml, tools/, .gitleaks.toml) e os docs atuais.

Faça:
1. docs/ARCHITECTURE.md: marcar por parte o que está implementado (Áudio, STT, Detector, Retrieval, LLM, Formatter, Lens simulada, Persistência com ConversationStore e SettingsStore, Segredos/Keychain, UI T01 a T05 e T07, composição AppEnvironment production/preview) e o que NÃO está (módulo Glasses/DAT SDK, óculos reais, T06 ligada ao hardware). Registrar as decisões já tomadas no código que ainda não estão escritas (ex.: caminho Q&A sem LLM quando não há chave, QANoteOnlyRetriever, limiares relidos por pergunta, ProductionAppRetriever). Não altere o status de aprovação existente.
2. docs/PRD.md: para cada história US-01 a US-14 acrescentar uma coluna ou linha de status: implementada e coberta por teste (nome do arquivo de teste real), parcial (diga o que falta) ou depende de hardware/decisão do Lucas. Seja fiel: verifique no código antes de marcar.
3. docs/TESTING.md: seção com o estado atual da suíte: número de testes (rode `xcodegen generate && xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build.noindex` e copie o total medido), gates de CI (SwiftLint, testes, cobertura do núcleo com tools/coverage-gate.sh, gitleaks), e o que continua manual.
4. docs/G1.md: adicionar uma seção "Fase 2 sem hardware" com SOMENTE números medidos por você agora: total de testes, cobertura por grupo (rode tools/coverage-gate.sh num .xcresult gerado com -enableCodeCoverage YES -resultBundlePath build.noindex/Test.xcresult), e referência aos números de latência/busca que já existem no arquivo. WER segue pendente (30 gravações humanas e asset pt-BR em iPhone físico): escreva isso explicitamente, sem estimativa. Proibido inventar métrica, estimar ou arredondar para cima.
5. README.md (se existir): estado atual e como rodar, em uma seção curta; não duplique o que está nos docs.

Regras: português, sem emoji, links relativos, tabelas existentes mantidas. Segredos: nunca escreva chave nem valor de configuração sensível. Salve este brief em docs/agentes/docs-sync.md.
Proibido: git commit, git push, merge, gh, editar código Swift, project.yml e .github/.
Entregue: resumo de 5 linhas com os números medidos.
