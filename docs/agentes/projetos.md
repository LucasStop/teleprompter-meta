# Tarefa: projetos, um chat e uma pasta por projeto (issue #105)

Protótipo aprovado pelo Lucas em 2026-11-09: `design/prototypes/t02-sessao.html` (estados `projetos`, `novo`, `excluir`), `t04-importacao.html` e `t07-conversas.html` (linha do projeto ativo). Abra no navegador e implemente exatamente como ele. Plano de origem: um chat e um material por projeto, sem vazamento de trecho entre projetos (RAG fechado, ADR-0009).

## Comportamento
- **Modelo**: `Project` (`id` String estável, `name`, `createdAt`) e `ProjectStore` atrás de protocolo (`list`, `create(name:)`, `rename`, `delete`), com implementação SQLite pequena (`projects.sqlite` em Application Support) e fake em memória para teste. Nome vazio ou só espaços é recusado; nome duplicado (sem diferenciar caixa) é recusado. Projeto "Padrão" (`id` fixo `default`) é criado na primeira abertura e não pode ser excluído, mas pode ser renomeado.
- **Projeto ativo**: `activeProjectId` em `Settings` (`SettingsStore`), padrão `default`. Decodificar `Settings` salvos antes deste campo não pode falhar (usar `decodeIfPresent`). Se o id ativo não existir mais, cai em `default`.
- **Índice isolado**: um SQLite por projeto, `index-<projectId>.sqlite`. O projeto `default` continua usando o `retriever.sqlite` atual, para não perder o material já importado (nada de cópia nem migração de dados). `ProductionAppRetriever` resolve o `LocalRetriever` do projeto ativo (cache por projeto e por limiares) e passa a ser o único ponto que conhece os arquivos. Trocar de projeto muda o índice usado por Chat, Ensaio e Material sem reiniciar o app. Apagar projeto apaga o arquivo do índice e as conversas dele.
- **Conversas**: coluna `project_id TEXT NOT NULL DEFAULT 'default'` em `conversations`, migração `user_version` 1 para 2, reversível (o `down` volta para 1 sem perder conversas). `list()` filtra pelo projeto ativo; `save` grava com o projeto ativo; conversa nova nasce no projeto ativo. `deleteAll` apaga só as do projeto ativo.
- **UI** (como o protótipo): linha do projeto ativo no cabeçalho do Chat e do Material (toque abre a folha de projetos), folha com lista, trocar, "Novo projeto" (campo de nome), renomear e excluir com confirmação destrutiva. Importar pasta e arquivo atuam sobre o projeto ativo; reimportar substitui só o material daquele projeto. Troca de projeto limpa a conversa em tela e carrega o estado do novo projeto (vazio se não há material).
- Estado vazio do Chat de projeto sem material aponta para Material com o texto do protótipo.

## Testes (obrigatórios, nível conforme `docs/TESTING.md`)
Unitários: `ProjectStore` (criar, renomear, excluir, nome vazio e duplicado, Padrão protegido), migração de conversas (regressão: conversas antigas caem em `default`; `down` preserva), `Settings` antigo sem `activeProjectId` decodifica. Integração com pasta temporária: dois projetos com materiais diferentes, pergunta no A nunca devolve fonte do B; reimportar no A não altera o B; excluir apaga o arquivo do índice e as conversas; `default` segue usando `retriever.sqlite`. ViewModel: trocar projeto atualiza lista de conversas e limpa o chat. Estados novos nos `*Previews`. Sem teste de CSS/layout.

## Docs no mesmo PR
`docs/adr/0010-projetos-com-indice-isolado.md` (status "proposta"; decisão: arquivo SQLite por projeto em vez de filtro por coluna, `default` herda `retriever.sqlite`; consequências e alternativa descartada), `docs/PRD.md` (nova história de projetos com critérios dado/quando/então), `docs/ARCHITECTURE.md` (Project, ProjectStore, resolução do índice), `docs/DATA.md` (arquivos por projeto, `project_id`, migração 1 para 2 e `down`), `docs/TESTING.md` (linhas das partes novas), `DESIGN.md` (linha do seletor de projeto, se ainda não houver), `design/telas.md` (T02: implementada, sem trocar a data de aprovação).

## Rodar de verdade
`xcodegen generate`, `swiftlint --strict`, `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17 - Meta'` (unit e UI) até verde. Use só o simulador `iPhone 17 - Meta`. Não use os simuladores "OParceiro".

## Arquivos permitidos
`Teleprompter/**`, `TeleprompterTests/**`, `TeleprompterUITests/**`, os docs listados, este brief. `project.yml` só se um arquivo novo exigir. Sem dependência nova. Sem texto de pergunta em log.

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain real, editar `.github/`, editar `.xcodeproj` à mão.

## Entregue
Resumo de 5 linhas: o que mudou, testes novos, resultado dos gates e o que só dá para validar no iPhone (troca de projeto com a pasta real).
