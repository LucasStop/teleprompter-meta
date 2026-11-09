# Tarefa: template de IA no Chat com citação inline (issue #113)

Protótipo aprovado pelo Lucas em 2026-11-09: `design/prototypes/t02-sessao.html` (estados `conversa` e `fontes`). Abra no navegador e implemente exatamente como ele. Tokens e componentes no `DESIGN.md` (linhas `user-bubble`, "Mensagem de chat" e "Composer do chat"). Base da escolha: `docs/pesquisa-referencias.md`.

## Comportamento
- **Pergunta** (`MessageBubble`, papel `question` e `partial`): bolha com fundo `user-bubble` (token novo em `Colors.swift` e `Assets.xcassets`, claro #EFEBE4, escuro #232326), texto `foreground`, raio 20 pt, alinhada à direita, até 80% da largura. Some o fundo âmbar.
- **Resposta** (papel `answer`): sem bolha, sem borda, largura cheia, alinhada à esquerda. Bullets e corpo com markdown inline (manter `MessageBubble.markdown`, `nonisolated`).
- **Citação inline**: marcadores `[n]` no texto da resposta viram número sobrescrito pequeno em `primary` (SF Mono, peso semibold). Número fora do intervalo de fontes é removido. Sem marcador, nada aparece. Regra pura e testável (`CitationParser` ou extensão do `markdown`), sem SwiftUI.
- **Numeração**: as fontes da resposta são os caminhos únicos de `sources`, na ordem em que já chegam. O prompt do LLM (`StreamingAnswerGenerator.makeRequest`) numera o contexto pela mesma ordem de caminho único (`[1] Fonte: path`, trechos do mesmo arquivo sob o mesmo número) e o `defaultSystemPrompt` ganha uma linha pedindo `[n]` ao fim de cada tópico, só com números do contexto. `FoundationModelsAnswerGenerator` herda o mesmo prompt. Resposta pelo caminho rápido de Q&A (sem LLM) não tem marcador.
- **Lente**: nunca mostra `[n]`. Remover marcadores antes de `Lens.show` (regra de 3 a 5 linhas curtas continua).
- **Bloco de fontes** (`SourceChip` ou componente novo): cartão com borda `border`, raio `r-md`, título "N fontes do seu material" (N em `primary`, mono; "1 fonte" no singular) e chevron; toque abre e fecha; aberto lista uma fonte por linha com o número em `primary` e o caminho em mono `muted`, quebrando linha sem corte. Fechado por padrão. Acessível: botão com rótulo "Mostrar fontes" / "Ocultar fontes" e estado.
- **Rodapé**: a legenda atual (`caption`) vira linha com ponto `success` e texto "Na lente · <caption>" quando a resposta foi para a lente; sem o prefixo quando não foi (ex.: óculos desconectados).
- **Composer** (`ComposerField`): pílula com raio total, fundo `surface-raised`, borda `border`; botão redondo de 44 pt (microfone sem texto, enviar em `primary` com texto). Área do composer sem divisória superior e com fundo `background`.
- Não mudar: estados de escuta contínua, banners, seletor de projeto, lente (`LensTokens`), rolagem automática (`scrollSignature`).

## Testes (obrigatórios)
Unitários: parser de citação (`[1]` vira citação, `[9]` fora do intervalo some, texto sem marcador intacto, marcador colado em markdown como `**x**[2]`), remoção de marcadores para a lente, numeração do contexto no `makeRequest` (dois trechos do mesmo arquivo com o mesmo número, ordem igual à de `sources`), `DefaultSystemPromptTests` atualizado. `MessageBubbleMarkdownTests` segue verde. Estados novos nos previews do Chat (fontes fechadas e abertas, com e sem citação). Sem teste de layout.

## Docs no mesmo PR
`DESIGN.md` (ajustar se algo mudar na implementação), `design/telas.md` (T02: implementada, data de aprovação 2026-11-09), `docs/adr/0009-rag-fechado-no-chat.md` (nota: citação numerada no prompt), `docs/TESTING.md` (linha do parser de citação), `docs/ARCHITECTURE.md` se a responsabilidade de alguma parte mudar.

## Rodar de verdade
`xcodegen generate`, `swiftlint --strict`, `xcodebuild test -scheme Teleprompter -destination 'platform=iOS Simulator,name=iPhone 17 - Meta'` (unit e UI) até verde. Use só o simulador `iPhone 17 - Meta`. Não use os simuladores "OParceiro".

## Arquivos permitidos
`Teleprompter/**`, `TeleprompterTests/**`, `TeleprompterUITests/**`, os docs listados, este brief. Sem dependência nova. Sem texto de pergunta em log.

## Proibido
git commit, git push, merge, gh, ler .env ou Keychain real, editar `.github/`, editar `.xcodeproj` à mão.

## Entregue
Resumo de 5 linhas: o que mudou, testes novos, resultado dos gates e o que só dá para validar no iPhone (resposta real do Haiku com citações).
