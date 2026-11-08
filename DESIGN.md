# Teleprompter Meta — DESIGN.md

Design system do projeto. É a fonte única de identidade visual e de padrões de interface: o `/frontend-design` e o `/impeccable` leem este arquivo antes de gerar UI. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o que é deste repo.

Regra de fluxo: nenhuma tela é implementada antes de ter protótipo aprovado pelo Lucas (ver [Fluxo de protótipo e aprovação](#fluxo-de-protótipo-e-aprovação) e [design/telas.md](design/telas.md)). Mudança em token ou componente atualiza este arquivo no mesmo PR.

Status do design system: <PREENCHER: rascunho | aprovado em AAAA-MM-DD>
Sem UI própria (CLI, API, biblioteca): manter só as seções que existirem (saída de terminal, mensagens, docs, e-mails) e marcar as demais como "N/A".

## 1. Brand
- Produto: teleprompter com contexto: mostra resposta curta na lente do Ray-Ban Display e no iPhone.
- Público: eu, em apresentações e na banca; uso ocasional, sob pressão, olhando para a banca e não para a tela.
- Personalidade: calmo, direto, legível, discreto.
- Conceito visual: <PREENCHER: a ideia central que ancora ícone, cor e forma>
- Referências que gosto: <PREENCHER: produtos/sites cujo visual serve de norte, com o que pegar de cada um>
- Anti-referências: <PREENCHER: o que evitar>
- Logo / ícone: <PREENCHER: arquivos em design/brand/ e regras de uso: área livre, tamanho mínimo, fundos permitidos>

## 2. Princípios de design
- <PREENCHER: 3-5 princípios que desempatam decisões, ex.: "denso e rápido antes de bonito", "nunca esconder erro">

## 3. Tokens

Tokens vivem em código em `<PREENCHER: caminho, ex.: src/styles/tokens.css | tailwind.config.ts | Assets.xcassets>`. Este arquivo documenta; o código é a implementação. Componente nunca usa valor literal, só token.

### 3.1 Cor
Camada primitiva (paleta) e camada semântica (uso). Componentes só consomem a semântica.

| Token semântico | Claro | Escuro | Uso |
|---|---|---|---|
| `background` | <#hex> | <#hex> | Fundo da página |
| `surface` | <#hex> | <#hex> | Cartões, painéis, popovers |
| `surface-raised` | <#hex> | <#hex> | Modais, menus, elementos elevados |
| `foreground` | <#hex> | <#hex> | Texto principal |
| `muted` | <#hex> | <#hex> | Texto secundário, metadados |
| `border` | <#hex> | <#hex> | Divisórias e bordas |
| `primary` | <#hex> | <#hex> | Ação principal, links, foco |
| `primary-hover` | <#hex> | <#hex> | Hover e active do primário |
| `primary-foreground` | <#hex> | <#hex> | Texto sobre o primário |
| `success` | <#hex> | <#hex> | Confirmação |
| `warning` | <#hex> | <#hex> | Atenção |
| `danger` | <#hex> | <#hex> | Erro, ação destrutiva |
| `info` | <#hex> | <#hex> | Informação neutra |
| `focus-ring` | <#hex> | <#hex> | Anel de foco de teclado |
| `disabled` | <#hex> | <#hex> | Controle desabilitado |

- Dark mode: <PREENCHER: sim | não. Se sim, tokens semânticos trocam por tema; mesma hierarquia nos dois modos>
- Contraste: texto >= 4,5:1 (3:1 para texto grande e ícones de UI) contra o fundo, nos dois modos. Cor nunca é o único sinal de estado (acompanhar de ícone ou texto).
- Dados/gráficos: <PREENCHER: paleta categórica, sequencial e divergente, ou N/A>

### 3.2 Tipografia
- Display/heading: <PREENCHER> · Corpo: <PREENCHER> · Mono: <PREENCHER>
- Carregamento: <PREENCHER: fonte do sistema | self-host | Google Fonts, com fallback>

| Estilo | Tamanho / linha | Peso | Uso |
|---|---|---|---|
| `display` | <PREENCHER> | <PREENCHER> | Hero, números grandes |
| `h1` | <PREENCHER> | <PREENCHER> | Título de página |
| `h2` | <PREENCHER> | <PREENCHER> | Seção |
| `h3` | <PREENCHER> | <PREENCHER> | Subseção, título de cartão |
| `body` | <PREENCHER> | <PREENCHER> | Texto corrido |
| `body-sm` | <PREENCHER> | <PREENCHER> | Apoio, tabelas |
| `caption` | <PREENCHER> | <PREENCHER> | Legendas, metadados |
| `code` | <PREENCHER> | <PREENCHER> | Trechos e valores técnicos |

- Medida de linha: 45-75 caracteres no texto corrido. Tracking e pesos: <PREENCHER>.

### 3.3 Espaçamento e layout
- Grid base: <PREENCHER: 4 px | 8 px>. Escala: <PREENCHER: ex.: 4, 8, 12, 16, 24, 32, 48, 64>. Sem número mágico fora da escala.
- Container máximo: <PREENCHER> · Colunas: <PREENCHER> · Gutter: <PREENCHER>
- Breakpoints: <PREENCHER: ex.: sm 640, md 768, lg 1024, xl 1280>. Abordagem: <mobile-first | desktop-first>.
- Densidade: <compacta | confortável>. Alvo de toque mínimo: 44 x 44 pt (mobile).

### 3.4 Forma e elevação
- Raio: <PREENCHER: ex.: sm 4, md 8, lg 12, full> · Borda: <PREENCHER: largura>
- Sombra/elevação: <PREENCHER: níveis 0-3, ou nenhuma>
- Z-index: <PREENCHER: escala nomeada — dropdown, sticky, modal, toast>

### 3.5 Movimento
- Durações: <PREENCHER: ex.: rápida 120 ms, base 200 ms, lenta 320 ms> · Easing: <PREENCHER>
- Movimento só comunica mudança de estado ou relação espacial. Respeitar `prefers-reduced-motion` (ou "Reduzir movimento" no SO).

### 3.6 Iconografia e imagem
- Biblioteca de ícones: <PREENCHER: ex.: lucide, SF Symbols> · Tamanhos: <PREENCHER> · Traço: <PREENCHER>
- Imagens/ilustração: <PREENCHER: estilo, proporções, tratamento, texto alternativo obrigatório>

## 4. Componentes

Todo componente documenta: anatomia, variantes, tamanhos, estados e comportamento. Estados obrigatórios: padrão, hover, foco visível, ativo/pressionado, desabilitado, carregando, erro, vazio (quando faz sentido).

| Componente | Variantes | Tamanhos | Estados cobertos | Código | Teste |
|---|---|---|---|---|---|
| Botão | primary, secondary, ghost, destructive | sm, md, lg | todos | <PREENCHER: caminho> | componente + visual |
| Campo de texto | padrão, com ícone, com ajuda | md | padrão, foco, erro, desabilitado | | componente + a11y |
| Seleção (select, checkbox, radio, switch) | | | | | |
| Link | | | | | |
| Cartão / painel | | | | | |
| Tabela / lista | | | vazio, carregando, erro | | |
| Navegação (barra, abas, breadcrumb) | | | ativo, colapsado | | |
| Modal / diálogo / popover | | | | | |
| Toast / alerta / banner | | | | | |
| Avatar / selo / tag | | | | | |
| <PREENCHER: componentes específicos do produto> | | | | | |

Por componente, registrar em `design/components.md` (ou Storybook) a anatomia e a regra de uso; o que não tiver variante documentada não existe.

## 5. Padrões de interface
- Formulários: rótulo sempre visível, validação ao sair do campo, mensagem de erro ao lado do campo e acionável, foco vai para o primeiro erro.
- Feedback: <PREENCHER: quando usar toast, banner, inline, modal>. Ação destrutiva pede confirmação ou desfazer.
- Carregamento: <PREENCHER: skeleton | spinner | barra, e a partir de quantos ms>
- Estado vazio: explica o que é a área e oferece a próxima ação.
- Estado de erro: diz o que houve, o que fazer e permite tentar de novo.
- Navegação: <PREENCHER: estrutura, profundidade máxima, onde fica a ação principal>
- Tabelas e listas: <PREENCHER: ordenação, paginação, busca, seleção em massa>
- Responsividade: <PREENCHER: o que reflui, o que esconde, o que vira outro componente>

## 6. Acessibilidade
- Meta: WCAG 2.2 AA.
- Navegação completa por teclado, ordem de foco lógica, foco sempre visível.
- Semântica correta (landmarks, headings em ordem, rótulos, `aria-*` só onde o HTML nativo não resolve). Em app nativo: rótulos de acessibilidade e Dynamic Type.
- Alvos de toque e clique com tamanho mínimo; texto redimensionável até 200% sem perda.
- Verificação: axe-core no CI nos componentes e telas, mais passada manual de teclado e leitor de tela antes de release (ver `docs/TESTING.md`).

## 7. Conteúdo e microcopy
- Idioma da UI: <PREENCHER: pt-BR> · Tratamento: <PREENCHER: você, informal | formal> · Tom: <PREENCHER>
- Mensagens: curtas, no ativo, sem culpar o usuário; erro diz causa e próximo passo.
- Formatos: datas <PREENCHER>, moeda <PREENCHER>, números <PREENCHER>. Capitalização de botões e títulos: <PREENCHER>.
- Internacionalização: <PREENCHER: só pt-BR | idiomas previstos e onde vivem as strings>

## 8. Regras (anti "AI slop")
- Sem degradê arco-íris, emoji decorativo ou glassmorphism sem propósito.
- Sem cartão dentro de cartão, sem sombra em tudo, sem ícone genérico para preencher espaço.
- Um único primário por tela; hierarquia clara entre primário, secundário e terciário.
- Espaçamento consistente com a escala; sem números mágicos.
- <PREENCHER: outras regras específicas do projeto>

## Fluxo de protótipo e aprovação

Nenhuma tela é desenvolvida sem protótipo aprovado. O inventário e o status de cada tela ficam em [design/telas.md](design/telas.md); o passo a passo em [design/README.md](design/README.md).

1. Definir a tela a partir de uma história do `docs/PRD.md`.
2. Prototipar usando só tokens e componentes deste arquivo. Ferramenta: <PREENCHER: Figma | HTML em design/prototypes/ | canvas>.
3. Cobrir os estados (padrão, vazio, carregando, erro) e os breakpoints/plataformas do projeto.
4. Lucas revisa e aprova; a data e o link entram em `design/telas.md`.
5. Só então implementar. A implementação é comparada com o protótipo (captura em `design/screenshots/`) e o teste visual/E2E da tela referencia o aprovado.
6. Componente ou token novo exigido pela tela entra neste arquivo antes (ou junto) e passa pela mesma aprovação.

## Referências visuais
- <PREENCHER: links/prints de telas que representam o alvo>

## Histórico
- AAAA-MM-DD: criação do design system.
