# Tarefa: importar pasta inteira na T04 (issue #86)

Protótipo aprovado pelo Lucas em 2026-11-09: `design/prototypes/t04-importacao.html` (abra no navegador; estados vazio, padrão, carregando, erro, pasta confirmar, pasta indexando, pasta concluído, pasta erro). Implemente exatamente como ele.

## Comportamento
- Botão "Importar pasta" ao lado de "Importar arquivo" (`.fileImporter` com `[.folder]`). Acesso por `startAccessingSecurityScopedResource` e liberado ao fim.
- Varredura recursiva em serviço testável atrás de protocolo (`FolderScanning`), sem SwiftUI. Entrada: URL da pasta. Saída: lista de arquivos válidos (caminho relativo, tipo) e lista de ignorados por motivo.
  - Extensões válidas: `md txt swift ts tsx js php py json yml yaml`.
  - Ignora diretórios `.git node_modules build build.noindex DerivedData Pods vendor .next dist graphify-out`, arquivos ocultos, binários (não decodificam como UTF-8), arquivos > 500 KB. Teto de 500 arquivos válidos; acima disso, os restantes entram em ignorados com o motivo "acima do limite".
  - Classificação: caminho começando em `qa/` vira nota de Q&A; `README*` e `docs/**` viram documento; o resto vira código. Reaproveite o que `MaterialImporter` já faz por arquivo.
- Fluxo: escolher pasta, tela de confirmação (contagem por tipo e ignorados por motivo, botões "Importar N arquivos" e "Escolher outra pasta"), indexação com progresso por arquivo (nome do arquivo atual), resultado (arquivos e trechos, aviso dos ignorados). Erro de leitura: banner "Não consegui ler a pasta ..." e "Escolher a pasta de novo".
- Reimportar substitui os trechos da mesma fonte (`removeSource` antes de indexar), sem duplicar. Uma falha em um arquivo não aborta os demais; vira linha em ignorados.
- Indexação em lote sem bloquear a UI (tarefa assíncrona, progresso publicado no ViewModel).

## Testes (obrigatórios)
Unitários do scanner com pasta temporária (`FileManager`): extensões, diretórios ignorados, oculto, binário, > 500 KB, teto de 500, classificação por caminho. Teste de ViewModel (confirmar, progresso, concluído, erro) com scanner e indexador fake. Teste de integração: pasta temporária com 3 arquivos, importar, e `LocalRetriever` encontra um trecho. Estados novos entram no `MaterialViewPreviews`. Sem teste de CSS/layout.

## Docs no mesmo PR
`DESIGN.md` (componentes novos, se houver), `design/telas.md` (T04: implementada), `docs/ARCHITECTURE.md` (scanner), `docs/PRD.md` (US-11), `docs/TESTING.md`.

## Rodar de verdade
`xcodegen generate`, `swiftlint --strict`, `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17 - Meta'` (unit e UI) até verde. Use só o simulador `iPhone 17 - Meta`. Não use os simuladores "OParceiro".

## Arquivos permitidos
`Teleprompter/**`, `TeleprompterTests/**`, `TeleprompterUITests/**`, `project.yml`, os docs listados, este brief. Sem dependência nova.

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain real, editar `.github/`.

## Entregue
Resumo de 5 linhas: o que mudou, testes novos, resultado dos gates e o que só dá para validar no iPhone (pasta real com permissão do sistema).
