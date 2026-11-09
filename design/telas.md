# Inventário de telas — Teleprompter Meta

Fluxo e regras em [README.md](README.md). Tela só vai para desenvolvimento com status `aprovada`.

| ID | Tela / fluxo | História (PRD) | Estados prototipados | Protótipo | Status | Aprovada em | Notas |
|---|---|---|---|---|---|---|---|
| T01 | Lente simulada (600x600) | US-05, US-06 | vazio, carregando, padrão (resposta), erro | design/prototypes/t01-lente.html | implementada | 2026-11-08 | Implementada como painel do chat (issue #23, PR #55) |
| T02 | Chat da sessão no iPhone (mensagens, texto, microfone, escuta contínua, fontes) | US-01 a US-04, US-12, US-13 | vazio, digitando, escuta, carregando, conversa, sem material, erro, desconectado | design/prototypes/t02-sessao.html | implementada | 2026-11-08 | Implementada na issue #23 (PR #55) e integração #60 (PR #63) |
| T07 | Lista de conversas | US-14 | vazio, padrão | design/prototypes/t07-conversas.html | implementada | 2026-11-08 | Implementada na issue #25 (PR #61) |
| T03 | Configurações (formato, limiares, fontes de contexto, provedores de LLM) | US-07 | padrão, login, loginErro, apple, custom, erro | design/prototypes/t03-config.html | implementada | 2026-11-09 | Implementada na issue #15 (PR #59); reaprovada e atualizada na issue #75 (Apple, OpenRouter OAuth PKCE e Personalizado) |
| T04 | Importação de material | US-11 | vazio, padrão, carregando, erro | design/prototypes/t04-importacao.html | implementada | 2026-11-08 | Implementada na issue #19 (PR #58) |
| T05 | Ensaio com perguntas gravadas | US-01 a US-05 | vazio, padrão, rodando | design/prototypes/t05-ensaio.html | implementada | 2026-11-08 | Implementada na issue #50 (PR #62) |
| T06 | Pareamento e estado dos óculos | US-08 | desconectado, pareando, conectado, erro | design/prototypes/t06-oculos.html | aprovada | 2026-11-08 | depende do módulo Glasses e do DAT SDK (hardware, abril) |

Estados: padrão, vazio, carregando, erro (marcar os que se aplicam e foram prototipados).
Status: rascunho, em revisão, aprovada, implementada.

## Fluxos

| Fluxo | Telas | Protótipo navegável | Status |
|---|---|---|---|
| Pergunta ao vivo | T02, T01 | | implementada |
