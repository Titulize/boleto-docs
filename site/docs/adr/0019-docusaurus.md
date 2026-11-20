---
title: 'ADR 0019: Documentação viva com Docusaurus'
---

# ADR 0019: Documentação viva com Docusaurus

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

A documentação precisa viver junto ao código, ser revisada em PR e publicada sem custo.

## Decisão

Docusaurus 3, com conteúdo em Markdown e diagramas Mermaid, publicado no GitHub Pages pela pipeline. A estrutura:

- `arquitetura/`: diagramas C4 em Mermaid.
- `guias/`: como trabalhar no projeto.
- `adr/`: decisões de arquitetura.
- `runbooks/`: procedimentos operacionais.

A especificação OpenAPI do backend será publicada aqui a partir do Task 15. Links quebrados falham o build.

## Consequências

- Documentação versionada e revisada como código.
- O site roda localmente em container com `docker compose up docs`.
- O Docusaurus usa React, mesmo com o frontend em Angular. Isso afeta só o site de documentação.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Starlight (Astro) | Boa opção, mas o Docusaurus tem versionamento de docs e Mermaid prontos |
| MkDocs Material | Entrou em modo de manutenção |
| Wiki do GitHub | Fora do fluxo de PR |
