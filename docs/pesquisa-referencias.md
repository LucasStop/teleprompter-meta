# Pesquisa de referências: apps parecidos e templates de chat

Feita em 2026-11-09 (issue #109). Base para escolher o template do Chat (dor principal: mensagens, fontes, composer, markdown). Fontes são em boa parte blogs, reviews e páginas de fornecedor; números de preço e latência valem como direção, não como fato.

## O que o Teleprompter Meta é, em uma linha

Chat com RAG fechado sobre o material do próprio usuário, separado por projeto, com resposta curta espelhada na lente do Ray-Ban Display, pensado para responder a banca sem olhar para o celular. A combinação "material próprio + lente + resposta em segundos" é o que nenhuma referência abaixo junta.

## 1. Teleprompter

| App | O que faz | Diferença para nós | Vale copiar |
|---|---|---|---|
| PromptSmart (Lite, Pro, +) | Teleprompter com VoiceTrack: segue a fala e rola o texto; reconhecimento no aparelho; para quando a pessoa sai do roteiro | Roteiro fixo, sem pergunta nem busca | Reconhecimento local e "segurar a posição" quando a fala sai do esperado; reviews reclamam do microfone interno, igual ao nosso risco de WER |
| Meta Ray-Ban Display (teleprompter nativo, pós-CES 2026) | Mostra um roteiro colado na lente direita; avança por gesto na Neural Band | Texto estático, sem IA | Avanço por gesto e lente só com texto: confirma a regra de 3 a 5 linhas e nada de rolar enquanto lê |
| Even Realities G1/G2 (Teleprompt) | Teleprompter com modos IA, manual e automático; G2 traz o "Conversate", assistente de conversa | Mais próximo da visão, mas sem RAG sobre material próprio | Modos de avanço (IA, manual, auto) e assistente de conversa na lente; reviews apontam que exige muito celular |

## 2. Copiloto ao vivo (reunião e entrevista)

| App | O que faz | Diferença para nós | Vale copiar |
|---|---|---|---|
| Cluely, LockedIn AI | Respostas em tempo real durante reunião ou entrevista, com foco em ficar invisível | Conhecimento geral do modelo, foco em esconder; latência relatada de 2 a 4 s | Nada do lado "invisível"; o nosso uso é declarado e permitido pela banca |
| Final Round AI | Copiloto ao vivo + preparação (simulados, currículo) | Mistura treino e ao vivo | O par treino/ao vivo já existe aqui como Ensaio e Chat; vale deixar essa ligação mais visível |
| Otter, Granola | Transcrição e notas de reunião; Granola melhora as notas do usuário com o áudio e tem chat sobre as reuniões | Pós-reunião, não ao vivo | Granola: o material do usuário é o centro e a IA complementa; o chat do Granola é criticado por ser fraco, alerta para o nosso retriever |

## 3. Chat de IA (padrão visual do mercado)

| App | Padrão de mensagem | Fontes | Composer |
|---|---|---|---|
| ChatGPT (iOS) | Pergunta do usuário em bolha cinza suave à direita (raio grande, até ~78% da largura); resposta da IA sem bolha, texto corrido à esquerda em largura cheia | Cartões de fonte quando busca na web | Pílula arredondada com borda fina e botão de enviar redondo de 44 pt |
| Claude, Gemini, Le Chat | Mesmo padrão: usuário em bolha, IA sem bolha | Fontes ao fim da resposta | Pílula com ações (anexo, voz) |
| Perplexity | Resposta direta primeiro, em prosa limpa, com números pequenos de citação no ponto exato da afirmação | Citações numeradas clicáveis e cartões de fonte acima ou abaixo | Busca como ação principal |
| NotebookLM | Chat no centro, fontes ao lado | Citação inline leva ao trecho exato da fonte; fontes ligadas e desligadas por caixa de seleção | Sugestões de pergunta |

Conclusão de padrão: o mercado convergiu para **usuário em bolha, IA sem bolha**, com **citação numerada inline** e **fontes agrupadas** ao fim. Hoje o nosso Chat usa bolha nos dois lados e lista de fontes solta abaixo da bolha da IA.

## 4. Memória e "segundo cérebro"

| App | O que faz | Vale copiar |
|---|---|---|
| Mem | Notas pessoais com chat sobre toda a biblioteca | Pergunta sobre "tudo o que eu escrevi", sem curadoria manual |
| Limitless (pendente) | Grava conversas e vira memória pesquisável | Tempo como eixo de busca; fora do nosso escopo |
| NotebookLM | Cadernos com fontes próprias, chat restrito às fontes | É o modelo mais próximo do nosso projeto + material: um caderno por assunto, fontes visíveis, resposta citada |

## 5. Óculos e plataforma

- Meta abriu a Ray-Ban Display a desenvolvedores em 2026-05-14 (preview): SDK móvel (Wearables Device Access Toolkit, o nosso caminho) e web apps; distribuição só por canal de teste até 100 pessoas. Confirma o ADR-0008 (DAT SDK isolado e versões fixadas).
- Even Hub (G2) abriu para terceiros em 2026-03: alternativa de hardware se a Meta travar.

## 6. Templates de chat

| Candidato | Tipo | Licença e dependência | Roda sem backend | Fontes/citações | Markdown e streaming | Esforço |
|---|---|---|---|---|---|---|
| A. exyte/Chat | Biblioteca SwiftUI (iOS 16+) | MIT, dependência nova (SPM) | Sim | Não tem; seria célula customizada | Markdown sim; streaming não é o foco | Médio: é feito para mensageiro (mídia, áudio, bolha dos dois lados) e brigaria com o padrão de IA |
| B. Padrão ChatGPT/Claude recriado | Referência visual recriada com componentes próprios | Sem dependência | Sim | Citação numerada inline + bloco "N fontes" (Perplexity/NotebookLM) | `AttributedString` atual; streaming já existe | Baixo a médio: muda `MessageBubble`, `SourceChip`, `ComposerField` e tokens |
| C. Anatomia Vercel AI Elements | Kit web (React/shadcn) usado como mapa de componentes | Sem dependência (só referência) | Sim | `Sources` recolhível e `InlineCitation` | `Response` com markdown; `Reasoning` | Igual ao B; serve para nomear e cobrir os estados |
| D. Stream Chat SwiftUI AI | SDK com componentes de IA (mensagem em streaming, indicador, composer, voz) | Exige o serviço Stream | Não | Não confirmado | Sim | Alto e fora da regra de RAG local |
| Complementar: Microsoft SwiftStreamingMarkdown | Renderizador de markdown em streaming | MIT, dependência nova | Sim | Não se aplica | Markdown de bloco (listas, títulos) durante o streaming | Só se o markdown inline atual não bastar |

**Recomendação: B com a anatomia do C.** É o template que o usuário já conhece de ChatGPT/Claude, não traz dependência nem ADR novo, e encaixa citações e fontes como Perplexity e NotebookLM, que é o nosso caso de uso (resposta presa ao material). A IDV "palco escuro" fica na lente e no acento âmbar; o Chat ganha a estrutura do mercado.

## Fontes
- Even Realities: [teleprompter glasses](https://evenrealities.com/teleprompter-glasses), [review G1 TechRadar](https://www.techradar.com/computing/even-realities-g1-review), [review G1 Engadget](https://www.engadget.com/wearables/even-realities-g1-review-limited-but-effective-smart-glasses-140059586.html), [review G2](https://www.geeky-gadgets.com/even-realities-g2-review/)
- Meta Ray-Ban Display: [toolkit para desenvolvedores](https://allcom.se/2026/05/18/meta-opens-ray-ban-display-glasses-to-third-party-developers-through-wearables-toolkit/), [atualizações CES 2026](https://www.androidcentral.com/apps-software/meta/meta-ray-ban-display-updates-ces-2026)
- PromptSmart: [App Store Pro](https://apps.apple.com/us/app/id894811756), [SpeechTech](https://www.speechtechmag.com/Articles/News/Speech-Technology-News/PromptSmart-Launches-Teleprompter-App-with-Voice-Recognition---98763.aspx)
- Copilotos: [hedy.ai](https://hedy.ai/post/best-ai-interview-assistant-tools/), [Final Round vs Cluely](https://dev.to/finalroundai/final-round-ai-vs-cluely-which-ai-actually-helps-developers-when-it-matters-most-4mpo), [AceRound](https://www.aceround.app/en/blog/best-ai-interview-copilot-2026/)
- Memória: [Granola](https://thesweetbits.com/tools/granola-ai-review/), [assistentes de reunião 2026](https://www.youngju.dev/blog/culture/2026-05-16-ai-productivity-meeting-assistants-2026-granola-otter-fathom-fireflies-fellow-read-ai-mem-reflect-spinach-deep-dive.en), [Granola vs Limitless](https://aiagentrank.io/compare/granola-vs-limitless)
- Chat de IA: [ChatGPT mobile design](https://screensdesign.com/articles/chatgpt-mobile-app-design/), [mockup ChatGPT](https://claudeskills.info/skills/gooseworks-ai/goose-skills/create-chatgpt-mockup/), [Perplexity design breakdown](https://www.925studios.co/blog/perplexity-design-breakdown), [NotebookLM citações](https://blog.google/technology/ai/notebooklm-goes-global-support-for-websites-slides-fact-check/), [NotebookLM ajuda](https://support.google.com/notebooklm/answer/14276569?hl=en)
- Templates: [exyte/Chat](https://github.com/exyte/Chat), [Stream AI SwiftUI](https://getstream.io/blog/swiftui-ai-chat-components/), [SwiftStreamingMarkdown](https://theresanaiforthat.com/company/microsoft/repository/SwiftStreamingMarkdown/), [Vercel AI Elements](https://examples.vercel.com/academy/ai-sdk/ai-elements)
