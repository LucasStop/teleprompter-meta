# design/ — protótipos e aprovação

Aqui vivem os artefatos de design de Teleprompter Meta. O sistema de design em si (tokens, componentes, regras) está em [../DESIGN.md](../DESIGN.md).

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `telas.md` | Inventário de telas com status de aprovação. Fonte de verdade do que pode ser implementado |
| `prototypes/` | Protótipos (HTML, exportações do Figma/canvas, links). Um por tela ou fluxo |
| `screenshots/` | Capturas da implementação, para comparar com o protótipo aprovado |
| `brand/` | Logo, ícones e arquivos mestre (criar quando existirem) |
| `components.md` | Anatomia e regras de uso de cada componente (opcional, ou usar Storybook) |

## Regra

Tela sem status `aprovada` em `telas.md` não é implementada. Isso vale para tela nova e para mudança visual relevante em tela existente.

## Passo a passo

1. Escolher a tela em `telas.md` (ou adicionar uma linha) e ligar à história do PRD.
2. Prototipar com tokens e componentes do `DESIGN.md`. Cobrir padrão, vazio, carregando e erro, em todos os breakpoints/plataformas do projeto.
3. Salvar ou linkar o protótipo em `prototypes/` e mudar o status para `em revisão`.
4. Lucas revisa. Ajustes voltam ao passo 2. Aprovado: status `aprovada`, com data e link.
5. Implementar em branch própria. O PR cita a linha de `telas.md` e anexa captura da implementação.
6. Comparar implementação e protótipo. Divergência intencional atualiza o protótipo (e o `DESIGN.md`) antes do merge.
7. Depois do merge, status `implementada`.

## Status

`rascunho` -> `em revisão` -> `aprovada` -> `implementada`. Mudança de requisito em tela já aprovada volta para `em revisão`.
