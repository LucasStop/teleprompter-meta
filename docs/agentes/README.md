# Orquestração com agy

O trabalho pesado (testes, código, build, correção de erro) é de workers `agy` com `gemini-3.8-flash-high`; o Claude despacha, revisa o diff e opera o GitHub. Regra e papéis em [AGENTS.md](../../AGENTS.md).

Fluxo por tarefa:
1. Issue `N-slug` e brief em `docs/agentes/<tarefa>.md` (template abaixo).
2. `tools/agy-run.sh N slug docs/agentes/<tarefa>.md`: cria o worktree `../tp-N`, roda o agy e imprime `git status` e os gates.
3. Claude revisa `git diff` e testes contra o aceite e os ADRs. Se falhar: `tools/agy-run.sh N slug <brief-de-feedback.md> --continue` (até 2 rodadas).
4. Claude faz commit (Conventional Commits com corpo), push e PR `Closes #N`; merge só pelo Lucas.
5. Depois do merge: apagar branch local e `git worktree remove ../tp-N`.

Modo: `--mode auto` não está disponível nesta conta (testado em 2026-11-08); o padrão é `accept-edits`, e em modo `-p` o agy rodou `xcodegen`, `swiftlint` e `xcodebuild test` sem pedir permissão. Se travar, `AGY_SKIP=1` (só em worktree descartável).

## Template de brief
```
# Tarefa: <título> (issue #N)
Objetivo: <1 frase>
Aceite (copiado do PRD): <dado/quando/então>
Leia antes: docs/PRD.md (US-xx), docs/API.md, docs/adr/000x-*.md, TeleprompterTests/ (padrão de teste e fakes)
Arquivos permitidos: <lista>
Faça: escreva os testes primeiro, depois o código; rode xcodegen generate, swiftlint --strict e xcodebuild test (iPhone 17) até ficar verde; atualize docs/API.md e docs/TESTING.md se o contrato mudar.
Regras: iOS 17.2+, Swift 6, um protocolo por etapa, DAT SDK só em Teleprompter/Glasses, sem dependência nova, sem texto de fala em log, comentário só quando o porquê não é óbvio.
Proibido: git commit/push/merge, gh, ler .env ou Keychain, editar .github/ e project.yml (salvo se listado acima).
Entregue: resumo de 5 linhas do que mudou e do resultado dos gates.
```
