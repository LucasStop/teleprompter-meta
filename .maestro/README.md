# Testes de Fluxo com Maestro — Teleprompter Meta

Testes end-to-end de fluxo entre telas locais executados pelo Maestro contra o simulador iOS (iPhone 17).

> [!NOTE]
> Conforme definido em `docs/TESTING.md`, os fluxos do Maestro rodam exclusivamente em ambiente de desenvolvimento local (pré-release / gates manuais), enquanto os testes unitários, de integração e XCUITest (smoke/a11y) rodam no CI.

## Identificador do aplicativo (appId)
`br.com.lucasstop.teleprompter`

## Requisitos
1. **Xcode** com SDK iOS 17.2+ e simulador `iPhone 17`.
2. **XcodeGen** (`brew install xcodegen`).
3. **Maestro CLI** (`brew install mobile-dev-inc/tap/maestro` ou `curl -FsSL "https://get.maestro.mobile.dev" | bash`).

## Como rodar

### 1. Gerar o projeto e compilar o app para o simulador
```bash
xcodegen generate
xcodebuild build -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build.noindex
```

### 2. Inicializar o simulador e instalar o app
```bash
xcrun simctl boot "iPhone 17" || true
xcrun simctl install booted build.noindex/Build/Products/Debug-iphonesimulator/Teleprompter.app
xcrun simctl launch booted br.com.lucasstop.teleprompter
```

### 3. Executar toda a suíte de fluxos
```bash
maestro test .maestro/
```

Ou executar um fluxo individualmente:
```bash
maestro test .maestro/01-abas.yaml
maestro test .maestro/02-chat-texto.yaml
maestro test .maestro/03-material.yaml
maestro test .maestro/04-ajustes.yaml
maestro test .maestro/05-ensaio.yaml
maestro test .maestro/06-conversas.yaml
```

## Fluxos incluídos

| Arquivo | Descrição | Telas validadas |
|---|---|---|
| `01-abas.yaml` | Valida a navegação entre as 4 abas inferiores (Chat, Material, Ensaio, Ajustes) e o retorno ao Chat | T02, T04, T05, T03 |
| `02-chat-texto.yaml` | Digita pergunta no campo de texto, envia, valida resposta "Não encontrei", abre e fecha a lente simulada | T02, T01 |
| `03-material.yaml` | Valida exibição da aba Material, estado vazio/padrão e botão de importar material | T04 |
| `04-ajustes.yaml` | Altera o formato de resposta da lente (Palavras-chave) e aciona a restauração para os valores padrão | T03 |
| `05-ensaio.yaml` | Valida estado vazio com instruções e botão para adicionar áudios de teste | T05 |
| `06-conversas.yaml` | Abre a lista de conversas pelo cabeçalho do Chat e retorna ao chat | T02, T07 |

## Identificadores de Acessibilidade (`accessibilityIdentifier`)

Para garantir seletores estáveis entre versões e temas sem depender unicamente de formatação de texto dinâmico, os seguintes identificadores foram adicionados:

| Identificador | Componente / Elemento | Tela |
|---|---|---|
| `chat-title` | Título da tela Chat | T02 |
| `chat-conversas-button` | Botão no cabeçalho para abrir a lista de conversas | T02 |
| `chat-lens-button` | Botão no cabeçalho para abrir a lente simulada | T02 |
| `chat-composer-field` | Seção do campo de pergunta e envio de texto | T02 |
| `lens-modal-close-button` | Botão "Fechar" da folha modal da lente simulada | T01 |
| `conversas-title` | Título da tela de histórico de conversas | T07 |
| `conversas-back-button` | Botão "Chat" para retornar ao chat da sessão | T07 |
| `conversas-delete-all-button` | Botão "Apagar todas as conversas" | T07 |
| `material-title` | Título da aba Material | T04 |
| `material-import-button` | Botão "Importar material" | T04 |
| `material-empty-title` | Título do estado vazio de material | T04 |
| `ensaio-title` | Título da aba Ensaio | T05 |
| `ensaio-empty-title` | Título do estado vazio de ensaio | T05 |
| `ensaio-empty-instruction` | Texto de instrução do estado vazio | T05 |
| `ensaio-add-audios-button` | Botão "Adicionar áudios" | T05 |
| `choice-Bullets` | Opção "Bullets" do formato de resposta | T03 |
| `choice-Palavras-chave` | Opção "Palavras-chave" do formato de resposta | T03 |
| `choice-Texto` | Opção "Texto" do formato de resposta | T03 |
| `settings-restore-defaults-button` | Botão "Restaurar padrões" em Ajustes | T03 |
