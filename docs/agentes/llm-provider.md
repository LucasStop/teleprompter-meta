# Tarefa: provedores Apple, OpenRouter (login) e Personalizado em T03 (issue #75)

Protótipo aprovado pelo Lucas em 2026-11-09: `design/prototypes/t03-config.html` (já está no seu worktree; abra no navegador e veja os 6 estados). Implemente a seção "Provedor de LLM" exatamente como ele: seletor segmentado Apple / OpenRouter / Personalizado.

## Comportamento
- `Settings.llmProvider` passa a aceitar `apple`, `openrouter` e `custom`, mais um `llmFormat` (`openai` | `anthropic`) usado só no `custom`. Migração na leitura (`SettingsStore`): valor salvo `openai` ou `anthropic` vira `custom` com esse formato, sem perder URL nem modelo. Decode retrocompatível, como já é feito hoje. Teste de regressão da migração.
- Chaves no Keychain separadas por provedor: a do OpenRouter não sobrescreve a do Personalizado (`SettingsConstants`, uma constante por chave; a atual `llm.apiKey` continua sendo a do Personalizado).
- `AppEnvironment.makeGenerator(settings:secretStore:)` (`Teleprompter/UI/AppEnvironment.swift`):
  - `apple`: `FoundationModelsAnswerGenerator()` se `FoundationModelsAnswerGenerator.isSupported`; senão `nil` (o chat cai no `QANoteOnlyRetriever`, como hoje sem chave). Ajustes mostra uma linha dizendo por que não está disponível.
  - `openrouter`: `StreamingAnswerGenerator` com base `https://openrouter.ai/api/v1`, formato `.openAI`, modelo do campo (padrão `anthropic/claude-haiku`, editável), chave do Keychain do OpenRouter.
  - `custom`: como hoje.
  - Testes unitários puros para cada ramo, com `InMemorySecretStore`.
- Login OpenRouter (OAuth PKCE, doc: https://openrouter.ai/docs/guides/overview/auth/oauth):
  1. Gerar `code_verifier` aleatório (32 bytes, base64url sem padding) e `code_challenge` = base64url(SHA256(verifier)) com `CryptoKit`.
  2. Abrir `https://openrouter.ai/auth?callback_url=teleprompter://openrouter&code_challenge=<c>&code_challenge_method=S256` com `ASWebAuthenticationSession` (`callbackURLScheme: "teleprompter"`, `prefersEphemeralWebBrowserSession = false`).
  3. Ler `code` da URL de retorno. `POST https://openrouter.ai/api/v1/auth/keys` com JSON `{"code","code_verifier","code_challenge_method":"S256"}`; a resposta tem `key`. Salvar no Keychain. Nunca logar `code`, `verifier` nem `key`.
  4. Estados da tela: desconectado (botão "Entrar com OpenRouter"), conectado (máscara `••••` com os 4 últimos e "Sair", que apaga a chave do Keychain), erro ("Login cancelado ou recusado. Tente de novo.").
  - Separe em um serviço testável atrás de protocolo (`OpenRouterAuthenticating`): geração PKCE, montagem da URL de auth, parse do callback e troca do code por key com `URLSession` injetável. Testes unitários com `URLProtocol` stub cobrindo sucesso, `code` ausente, HTTP 4xx e JSON sem `key`. A parte do `ASWebAuthenticationSession` fica numa casca fina sem lógica.
  - Registrar o URL scheme `teleprompter` no `project.yml` (permitido neste brief) via `INFOPLIST_KEY_CFBundleURLTypes` ou `info.properties` do XcodeGen, o que funcionar; confira no Info.plist gerado.
- `tools/llm-bench.sh`: copie de `docs/agentes/llm-bench.sh` (já no worktree) para `tools/`, `chmod +x`, e documente o uso em `docs/TESTING.md`.

## Docs no mesmo PR
`DESIGN.md` (componente novo: botão de login e linha "conectado"), `design/telas.md` (T03: estados novos, protótipo reaprovado em 2026-11-09), `docs/ARCHITECTURE.md` (provedores e fluxo OAuth), `docs/API.md` (as duas chamadas ao OpenRouter), `docs/PRD.md` se a história mudar, `docs/TESTING.md`.

## Rodar de verdade
`xcodegen generate`, `swiftlint --strict`, `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17 - OParceiro #2'` (unit e UI) até verde. Não use `iPhone 17 - OParceiro #1`. Não faça chamada real ao OpenRouter nos testes.

## Arquivos permitidos
`Teleprompter/**`, `TeleprompterTests/**`, `TeleprompterUITests/**`, `project.yml`, `tools/llm-bench.sh`, os docs listados, este brief. Sem dependência nova (CryptoKit e AuthenticationServices são do sistema).

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain real, editar `.github/`.

## Entregue
Resumo de 5 linhas: o que mudou, testes novos, resultado dos gates e o que só dá para validar no iPhone com a conta do Lucas (login real).
