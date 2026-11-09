# Tarefa: fluxos Maestro locais e status das telas (issue #65)

Objetivo: pasta `.maestro/` com fluxos YAML que validam o fluxo entre as telas T02 a T07 contra o app rodando no simulador iPhone 17, e `design/telas.md` com o status real de cada tela.

Decisão já tomada (`docs/TESTING.md`): Maestro roda só local; XCUITest cobre smoke e acessibilidade no CI. Não crie workflow de CI para Maestro e não toque em `.github/`.

## Fluxos (um arquivo cada, nomes em português)
- `01-abas.yaml` (as 4 abas abrem: Chat, Material, Ensaio, Ajustes)
- `02-chat-texto.yaml` (digita pergunta no campo de texto e vê a resposta ou "Não encontrei" e o botão da lente simulada abre o painel)
- `03-material.yaml` (aba Material mostra o estado vazio ou padrão e o botão de importar)
- `04-ajustes.yaml` (muda o formato da resposta, vê restaurar padrão)
- `05-ensaio.yaml` (aba Ensaio mostra o estado vazio com instrução)
- `06-conversas.yaml` (botão Conversas no cabeçalho do chat abre a lista e volta)
- Mais `.maestro/config.yaml` e `.maestro/README.md` (como rodar: build do app no simulador, `maestro test .maestro/`, requisitos). Appid: `br.com.lucasstop.teleprompter`.

## Seletores
Use texto visível ou `accessibilityIdentifier`. Se faltar identificador estável em algum elemento, ADICIONE o modifier `.accessibilityIdentifier("...")` nas views (mudança mínima, só isso, sem alterar layout ou lógica) e liste os ids no README.

## Rodar de verdade
Gere o app (`xcodegen generate`, `xcodebuild build -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build.noindex`), instale e abra no simulador com `xcrun simctl` (install/launch) e rode `maestro test .maestro/`. Corrija os fluxos até passarem. Se o maestro não conseguir rodar por motivo do ambiente (driver, permissão), pare e reporte o erro exato em vez de inventar. O app não deve pedir permissão de microfone nos fluxos (não toque no microfone).

## design/telas.md
Marcar `implementada` as telas T02, T03, T04 (T05 e T07 já estão) com a issue/PR na coluna de notas se couber; T01 (lente simulada) também implementada como painel do chat; T06 (óculos) fica `aprovada` com nota "depende do módulo Glasses e do DAT SDK (hardware, abril)". Atualize a tabela de jornadas se houver status.

## Arquivos permitidos
- `.maestro/` (novo)
- `Teleprompter/UI/**/*.swift` (somente accessibilityIdentifier)
- `design/telas.md`
- `docs/TESTING.md` (seção do Maestro: como rodar e quais fluxos existem)
- `docs/agentes/maestro.md` (este brief)
Não edite `project.yml` nem `.github/`. Sem dependência nova.

## Regras
Swift 6, `swiftlint --strict` e `xcodebuild test` devem continuar verdes.

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain, editar .github/ e project.yml.

## Entregue
Resumo de 5 linhas com resultado do `maestro test` (fluxos que passaram) e dos gates.
