# Teleprompter Meta

Contexto do projeto para a CLI de IA. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o específico do repo. `CLAUDE.md` e `GEMINI.md` são symlinks para este arquivo.

## O que é
App iOS pessoal (Swift + Meta DAT SDK): ouve a pergunta da banca, busca no material do projeto e mostra resposta curta na lente do Ray-Ban Display. Detalhe em docs/PRD.md.
Perfil: monolito · Stack: Swift (SwiftUI, XcodeGen) (ver `.projeto.yml`)

## Documentação (ler antes de mexer)
- [docs/PRD.md](docs/PRD.md): problema, histórias e critérios de aceite
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): partes do sistema e decisões (ADR em docs/adr/)
- [docs/TESTING.md](docs/TESTING.md): quais testes valem para cada parte e como rodar
- [DESIGN.md](DESIGN.md): design system
- [design/telas.md](design/telas.md): inventário de telas e aprovação
- [docs/API.md](docs/API.md): contrato da API (OpenAPI), convenções de erro e versionamento
- [docs/DATA.md](docs/DATA.md): entidades, migrações, retenção e backup

## Regras de fluxo
- Mudança de comportamento atualiza PRD/ARCHITECTURE/TESTING no mesmo PR.
- Teste no nível certo conforme `docs/TESTING.md`; bug corrigido ganha teste de regressão.
- Estratégia de testes e arquitetura precisam de "aprovado em AAAA-MM-DD" (Lucas) antes da implementação.
- Perfil monólito: tela só é implementada com protótipo `aprovada` em `design/telas.md`. Sem aprovação, parar e pedir.
- Componente ou token novo entra no `DESIGN.md` antes ou junto da tela.
- Contrato e dados: endpoints em `docs/API.md` (mesmo que só a própria UI consuma), migrações reversíveis e `docs/DATA.md` atualizado.
- Mantenha fronteiras por módulo (domínio, persistência, web) mesmo no mesmo deploy; regra de negócio não mora em controller nem em componente.

## Comandos
- Instalar: `brew install xcodegen swiftlint && xcodegen generate`
- Dev: `xcodebuild -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Build: `xcodebuild -scheme Teleprompter -configuration Release build`
- Testes: `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 16'` · E2E: `xcodebuild test -scheme TeleprompterUITests -destination 'platform=iOS Simulator,name=iPhone 16'`
- Lint/typecheck: `swiftlint --strict`

## Convenções
- Swift 6 + SwiftUI (UIKit onde preciso); projeto gerado por XcodeGen (`project.yml` é a fonte, `.xcodeproj` não se edita à mão); alvo iOS 17.2+ (exigência do DAT SDK).
- Lógica em ViewModels/serviços testáveis, sem dependência de SwiftUI; efeitos de sistema (arquivo, processo, rede) atrás de protocolo para trocar por fake nos testes.
- Estrutura: `<App>/` (código), `<App>Tests/`, `<App>UITests/`, `project.yml`, `design/`.
- Depois de build/release, apagar `build.noindex/` e DerivedData; o app instalado fica só em `~/Applications/<App>.app`.
- Distribuição: sem assinatura de distribuição (uso pessoal), instalação direta no iPhone pelo Xcode.
- Cada etapa do pipeline (Audio, STT, Detector, Retrieval, LLM, Lens) é um protocolo; o DAT SDK só aparece no módulo `Glasses`.
- Sem óculos, desenvolver contra `SimulatedLens` e áudios gravados; o Mock Device Kit não simula display nem microfone.

## Notas do projeto
- Chave do provedor de LLM no Keychain, nunca no repo (ADR-005 a decidir). DAT SDK em developer preview: checar mudanças antes de atualizar.
- Estrutura real: `Teleprompter/`, `TeleprompterTests/`, `TeleprompterUITests/` (ainda não criados; fase 1).
