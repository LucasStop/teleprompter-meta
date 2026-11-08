# Teleprompter Meta — DESIGN.md

Design system do projeto. É a fonte única de identidade visual e de padrões de interface: o `/frontend-design` e o `/impeccable` leem este arquivo antes de gerar UI. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o que é deste repo.

Regra de fluxo: nenhuma tela é implementada antes de ter protótipo aprovado pelo Lucas (ver [Fluxo de protótipo e aprovação](#fluxo-de-protótipo-e-aprovação) e [design/telas.md](design/telas.md)). Mudança em token ou componente atualiza este arquivo no mesmo PR.

Status do design system: aprovado em 2026-11-08

Duas superfícies: o app no iPhone (SwiftUI) e a lente do Meta Ray-Ban Display (600x600 px, uma view enviada pelo módulo `Glasses`). Números marcados "a validar" valem como proposta até o teste no óculos real (gate G3).

## 1. Brand
- Produto: teleprompter com contexto: mostra resposta curta na lente do Ray-Ban Display e no iPhone.
- Público: eu, em apresentações e na banca; uso ocasional, sob pressão, olhando para a banca e não para a tela.
- Personalidade: calmo, direto, legível, discreto.
- Conceito visual: "palco escuro": fundo preto, texto claro e um único acento âmbar, como a luz de um teleprompter. A lente usa a mesma linguagem do app.
- Referências que gosto: nenhuma definida; adicionar ao fim do arquivo quando surgirem.
- Anti-referências: dashboards coloridos, animação chamativa, texto pequeno e denso.
- Logo / ícone: ainda não existe; arquivos em `design/brand/` quando houver. Ícone do app: proposta no protótipo T01.

## 2. Princípios de design
- Legibilidade antes de beleza: o texto precisa ser lido num relance, a distância e sob pressão.
- Menos é mais na lente: no máximo 3 a 5 linhas curtas por resposta; nunca rolar, paginar ou animar texto enquanto se lê.
- Nunca esconder erro: se a pergunta não foi entendida, a rede caiu ou o óculos desconectou, mostrar isso com texto claro.
- Previsibilidade: o mesmo estado tem sempre a mesma cara no iPhone e na lente.

## 3. Tokens

Tokens vivem em código em `Teleprompter/DesignSystem/` (`Colors` em `Assets.xcassets` com variante clara e escura, `Typography.swift`, `Spacing.swift`). Este arquivo documenta; o código é a implementação. Componente nunca usa valor literal, só token.

### 3.1 Cor
Camada primitiva (paleta) e camada semântica (uso). Componentes só consomem a semântica.

| Token semântico | Claro | Escuro | Uso |
|---|---|---|---|
| `background` | #FAF8F4 | #0B0B0C | Fundo da página |
| `surface` | #FFFFFF | #151517 | Cartões, painéis, popovers |
| `surface-raised` | #FFFFFF | #1E1E21 | Modais, menus, elementos elevados |
| `foreground` | #1C1B19 | #F5F3EE | Texto principal |
| `muted` | #5F5B54 | #A3A09A | Texto secundário, metadados |
| `border` | #DDD8CF | #2C2C30 | Divisórias e bordas |
| `primary` | #A8560A | #F5A524 | Ação principal, foco, destaque |
| `primary-hover` | #8F4906 | #FFB84D | Pressionado do primário |
| `primary-foreground` | #FFFFFF | #1A1203 | Texto sobre o primário |
| `success` | #1F7A33 | #3FB950 | Confirmação |
| `warning` | #8A5A00 | #E3B341 | Atenção |
| `danger` | #C62828 | #F85149 | Erro, ação destrutiva |
| `info` | #0B5FB0 | #58A6FF | Informação neutra |
| `focus-ring` | #A8560A | #FFC857 | Anel de foco |
| `disabled` | #A9A49B | #5A5853 | Controle desabilitado |

- Dark mode: sim, e é o tema de referência. O app segue o tema do sistema (claro/escuro automático). A lente é sempre escura (fundo preto) e usa os valores do tema escuro.
- Contraste: texto >= 4,5:1 (3:1 para texto grande e ícones de UI) contra o fundo, nos dois modos. Cor nunca é o único sinal de estado (acompanhar de ícone ou texto). Valores conferidos à mão para `foreground`, `muted`, `primary` e `danger`; validar todos com ferramenta no protótipo.
- Lente: fundo preto puro (#000000); em tela aditiva o preto tende a ficar transparente (a validar no óculos). Só `foreground`, `muted` e `primary` na lente.
- Dados/gráficos: N/A (sem gráficos no MVP; métricas de latência em texto).

### 3.2 Tipografia
- Display/heading: SF Pro · Corpo: SF Pro · Mono: SF Mono
- Carregamento: fontes do sistema, sem arquivo próprio. Estilos mapeiam para `Font.TextStyle` e respeitam Dynamic Type no iPhone.

iPhone:

| Estilo | Tamanho / linha | Peso | Uso |
|---|---|---|---|
| `display` | 34 / 41 pt | Bold | Título da tela principal |
| `h1` | 28 / 34 pt | Bold | Título de página |
| `h2` | 22 / 28 pt | Semibold | Seção |
| `h3` | 17 / 22 pt | Semibold | Título de cartão |
| `body` | 17 / 24 pt | Regular | Texto corrido |
| `body-sm` | 15 / 20 pt | Regular | Apoio, listas |
| `caption` | 12 / 16 pt | Regular | Legendas, metadados |
| `code` | 15 / 20 pt | Regular (SF Mono) | Latência, versões, trechos técnicos |

Lente (600x600, tamanhos a validar no óculos):

| Estilo | Tamanho / linha | Peso | Uso |
|---|---|---|---|
| `lens-title` | 40 / 48 px | Semibold | Pergunta ou palavra-chave principal |
| `lens-body` | 32 / 42 px | Regular | Linhas da resposta |
| `lens-status` | 24 / 30 px | Medium | Estado (ouvindo, pensando, erro) |

- Medida de linha: 45-75 caracteres no texto corrido do iPhone; na lente, até 28 caracteres por linha e no máximo 5 linhas (a validar). Tracking padrão do sistema; pesos conforme as tabelas.

### 3.3 Espaçamento e layout
- Grid base: 4 pt. Escala: 4, 8, 12, 16, 24, 32, 48, 64. Sem número mágico fora da escala.
- Container máximo: largura da tela (iPhone) · Colunas: 1 · Gutter: 16 pt. Lente: margem segura de 32 px em volta (a validar).
- Plataformas: iPhone em retrato (iOS 17.2+); sem iPad nem paisagem no MVP. Abordagem: mobile-first.
- Densidade: confortável. Alvo de toque mínimo: 44 x 44 pt.

### 3.4 Forma e elevação
- Raio: sm 8, md 12, lg 16, full (pílula) · Borda: 1 pt em `border`
- Sombra/elevação: nenhuma; elevação por contraste de superfície (`background` < `surface` < `surface-raised`).
- Z-index: N/A em SwiftUI; ordem de empilhamento: conteúdo, banner, sheet, alerta.

### 3.5 Movimento
- Durações: rápida 120 ms, base 200 ms, lenta 320 ms · Easing: ease-out padrão do sistema.
- Movimento só comunica mudança de estado ou relação espacial. Respeitar "Reduzir movimento" do iOS (trocar por fade ou nada). Na lente: sem animação enquanto o texto está na tela.

### 3.6 Iconografia e imagem
- Biblioteca de ícones: SF Symbols · Tamanhos: 17 e 22 pt · Traço: peso regular, `hierarchical` quando houver
- Imagens/ilustração: sem ilustrações no MVP; ícone do app a definir. Texto alternativo (rótulo de acessibilidade) obrigatório em todo ícone sem texto.

## 4. Componentes

Todo componente documenta: anatomia, variantes, tamanhos, estados e comportamento. Estados obrigatórios: padrão, foco visível, pressionado, desabilitado, carregando, erro, vazio (quando faz sentido).

| Componente | Variantes | Tamanhos | Estados cobertos | Código | Teste |
|---|---|---|---|---|---|
| Botão | primary, secondary, ghost, destructive | md, lg | padrão, pressionado, desabilitado, carregando | `Teleprompter/DesignSystem/` (a criar) | componente + visual |
| Campo de texto | padrão, com ajuda | md | padrão, foco, erro, desabilitado | idem | componente + a11y |
| Seleção (segmented, toggle, stepper) | formato da resposta, limiares | md | padrão, selecionado, desabilitado | idem | componente + a11y |
| Cartão / painel | padrão, destaque | md | padrão, vazio | idem | visual |
| Lista | notas de Q&A, documentos | md | vazio, carregando, erro | idem | componente |
| Navegação | abas inferiores (Sessão, Material, Ensaio, Ajustes) | md | ativo | idem | E2E |
| Alerta / banner | info, warning, danger | md | padrão, dispensável | idem | visual |
| Selo de estado | ouvindo, transcrevendo, pensando, respondendo, erro, desconectado | sm | todos | idem | componente + visual |
| Mensagem de chat | pergunta, resposta (com fontes), não encontrei | md | padrão, parcial (fala), carregando (streaming), erro | idem | componente + visual |
| Compositor | texto, microfone, escuta contínua | md | vazio, digitando, ouvindo, desabilitado | idem | componente + a11y |
| Transcrição ao vivo | parcial, final | md | vazio, ativo, erro | idem | componente |
| Cartão de resposta | bullets, palavras-chave, texto completo | md | carregando (streaming), pronto, erro | idem | visual |
| `LensView` (lente 600x600) | bullets, palavras-chave, texto completo, status | 600x600 | ouvindo, pensando, resposta, erro, vazio | `Teleprompter/Lens/` (a criar) | visual + manual no óculos |

Por componente, registrar em `design/components.md` a anatomia e a regra de uso; o que não tiver variante documentada não existe.

## 5. Padrões de interface
- Formulários (Ajustes): rótulo sempre visível, validação ao sair do campo, mensagem de erro ao lado do campo e acionável.
- Feedback: banner para estado de conexão e erros de rede; inline para erro de campo; alerta modal só para ação destrutiva (limpar índice). Sem toast.
- Carregamento: resposta chega em streaming (texto aparece aos poucos, sem spinner); spinner só para importação a partir de 300 ms.
- Estado vazio: explica a área e oferece a próxima ação (ex.: "Importar material").
- Estado de erro: diz o que houve, o que fazer e permite tentar de novo; na lente, uma linha curta de status.
- Navegação: barra de abas com 4 destinos, profundidade máxima 2; compositor do chat (campo, enviar, microfone, escuta contínua) fixo na parte inferior.
- Listas: ordenação por mais recente, busca por texto nas notas, sem seleção em massa no MVP.
- Responsividade: só retrato no iPhone; Dynamic Type até a faixa de acessibilidade sem cortar texto (componentes crescem).
- Lente: uma pergunta/resposta por vez; nova resposta substitui a anterior sem transição; sem rolagem.

## 6. Acessibilidade
- Meta: WCAG 2.2 AA.
- Todo controle acessível por VoiceOver com rótulo, valor e ordem lógica; foco visível em teclado externo.
- Rótulos de acessibilidade em todos os ícones sem texto; Dynamic Type suportado em todos os textos do iPhone.
- Alvos de toque >= 44 x 44 pt; texto redimensionável até 200% sem perda.
- Reduzir movimento respeitado; estado nunca só por cor.
- Verificação: `performAccessibilityAudit` no XCUITest nas telas, mais passada manual de VoiceOver e Dynamic Type antes de cada gate (ver `docs/TESTING.md`).

## 7. Conteúdo e microcopy
- Idioma da UI: pt-BR · Tratamento: você, informal · Tom: calmo e direto.
- Mensagens: curtas, no ativo, sem culpar o usuário; erro diz causa e próximo passo.
- Formatos: datas DD/MM/AAAA, sem moeda no MVP, números com vírgula decimal. Capitalização de botões e títulos: só a primeira letra maiúscula.
- Internacionalização: só pt-BR; strings em `Localizable.xcstrings` para facilitar mudança futura.

## 8. Regras (anti "AI slop")
- Sem degradê arco-íris, emoji decorativo ou glassmorphism sem propósito.
- Sem cartão dentro de cartão, sem sombra em tudo, sem ícone genérico para preencher espaço.
- Um único primário por tela; hierarquia clara entre primário, secundário e terciário.
- Espaçamento consistente com a escala; sem números mágicos.
- O âmbar é o único acento: não usar para decoração, só para ação principal, foco e destaque do que está sendo lido.
- Na lente, nada que não seja texto de resposta ou status curto.

## Fluxo de protótipo e aprovação

Nenhuma tela é desenvolvida sem protótipo aprovado. O inventário e o status de cada tela ficam em [design/telas.md](design/telas.md); o passo a passo em [design/README.md](design/README.md).

1. Definir a tela a partir de uma história do `docs/PRD.md`.
2. Prototipar usando só tokens e componentes deste arquivo. Ferramenta: HTML em `design/prototypes/` (um arquivo por tela, tokens como variáveis CSS espelhando a tabela 3.1; a lente em moldura de 600x600 px).
3. Cobrir os estados (padrão, vazio, carregando, erro), claro e escuro e Dynamic Type grande no iPhone.
4. Lucas revisa e aprova; a data e o link entram em `design/telas.md`.
5. Só então implementar. A implementação é comparada com o protótipo (captura em `design/screenshots/`) e o teste visual/E2E da tela referencia o aprovado.
6. Componente ou token novo exigido pela tela entra neste arquivo antes (ou junto) e passa pela mesma aprovação.

## Referências visuais
- Sem referências ainda; adicionar links ou prints que representem o alvo.

## Histórico
- 2026-11-08: criação e aprovação do design system.
