# Teleprompter Meta

App iOS pessoal que ouve perguntas da banca, busca no meu material e mostra a resposta na lente do Meta Ray-Ban Display.

## Documentação
| Documento | Para quê |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Problema, solução, histórias e critérios de aceite |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Partes do sistema, dados, segurança, deploy |
| [docs/TESTING.md](docs/TESTING.md) | Testes por parte, comandos e definição de pronto |
| [docs/adr/](docs/adr/) | Decisões de arquitetura |
| [DESIGN.md](DESIGN.md) | Design system (tokens, componentes, regras) |
| [design/telas.md](design/telas.md) | Telas, protótipos e status de aprovação |
| [docs/API.md](docs/API.md) | Contrato da API, convenções, erros e versionamento |
| [docs/DATA.md](docs/DATA.md) | Modelo de dados, migrações, retenção e backup |

Perfil: monolito · Stack: Swift (SwiftUI, XcodeGen)

## Requisitos
- Swift 6, iOS 17.2+, Xcode 26.4+, XcodeGen, SwiftLint

## Começando
```bash
brew install xcodegen swiftlint && xcodegen generate
cp .env.example .env   # preencher valores; nunca commitar .env
xcodebuild -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Testes
```bash
xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17'
swiftlint --strict
```
Detalhes em [docs/TESTING.md](docs/TESTING.md).

## Contribuindo
- Trabalho começa numa issue; branch criada pela issue (`N-slug`).
- PR com `Closes #N`, título em Conventional Commits (`tipo(escopo): resumo`).
- UI: protótipo aprovado em `design/telas.md` antes de implementar.

## Licença
Licença MIT. Veja [LICENSE](LICENSE).
