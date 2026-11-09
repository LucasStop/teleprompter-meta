# Tarefa: target XCUITest de smoke e acessibilidade (issue #72)

Objetivo: cumprir o que `docs/TESTING.md` já aprovou. XCUITest no PR para smoke da jornada pergunta -> resposta e `performAccessibilityAudit`. Junto, limpar código morto e docs que citam comandos inexistentes.

## O que fazer
1. Em `project.yml` (permitido neste brief), criar o target `TeleprompterUITests` (`type: bundle.ui-testing`, `platform: iOS`, deployment 17.2, `TEST_TARGET_NAME: Teleprompter`, bundle id `br.com.lucasstop.teleprompter.uitests`, fontes em `TeleprompterUITests/`). Incluir o target no `test` do scheme `Teleprompter`, para que `xcodebuild test -scheme Teleprompter` rode unit e UI juntos (o CI já roda esse comando, então não mexa em `.github/`).
2. `TeleprompterUITests/SmokeUITests.swift`:
   - `testAskByTextShowsAnswerOrNotFound`: abre o app, digita uma pergunta no campo de texto do chat, envia e espera (timeout de até 10 s) uma resposta ou o texto "Não encontrei isso no seu material". Use os `accessibilityIdentifier` que já existem (veja `.maestro/README.md`). Não toque no microfone.
   - `testTabsPassAccessibilityAudit`: percorre as 4 abas (Chat, Material, Ensaio, Ajustes) e chama `try app.performAccessibilityAudit()` em cada uma (iOS 17+). Se uma auditoria falhar por problema real da view, corrija a view com a mudança mínima de acessibilidade (rótulo, traits ou tamanho do alvo, sem mudar o layout aprovado). Se a falha for falso positivo de componente do sistema, filtre só aquele issue no handler e explique o motivo num comentário de uma linha.
3. Apagar `Teleprompter/UI/ChatPlaceholderView.swift`, `MaterialPlaceholderView.swift` e `AjustesPlaceholderView.swift`, que só são usados pelo próprio `#Preview`. Confirme antes com grep que ninguém mais os usa.
4. `AGENTS.md` (CLAUDE.md e GEMINI.md são symlinks para ele): a linha 31 passa a dizer que unit e UI rodam no mesmo `xcodebuild test -scheme Teleprompter ...` e que o E2E de fluxo é `maestro test .maestro/` (local). Atualize também a linha 45 ("Estrutura real"), que diz que as pastas ainda não foram criadas.
5. `docs/TESTING.md` linha 72: o comando real do XCUITest. `.maestro/README.md`: manter a nota, agora verdadeira.

## Rodar de verdade
`xcodegen generate`, `swiftlint --strict`, `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17 - OParceiro #2'` até ficar verde. Relate quantos testes de unit e de UI rodaram. Não use o simulador `iPhone 17 - OParceiro #1`, que está em uso por outra sessão.

## Arquivos permitidos
`project.yml`, `TeleprompterUITests/` (novo), os 3 placeholders (apagar), `Teleprompter/UI/**/*.swift` (só acessibilidade), `AGENTS.md`, `docs/TESTING.md`, `.maestro/README.md`, este brief.

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain, editar `.github/`, dependência nova.

## Entregue
Resumo de 5 linhas: testes que rodaram (unit e UI), auditorias que passaram, correções de acessibilidade feitas e resultado dos gates.
