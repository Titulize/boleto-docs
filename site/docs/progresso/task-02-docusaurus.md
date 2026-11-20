---
sidebar_position: 2
title: 'Task 02: Docusaurus'
---

# Task 02: Site de documentação viva (Docusaurus)

- **Situação:** Concluída
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-20
- **Repositórios:** `boleto-docs`

## Objetivo

Publicar um site com a estrutura de documentação e as decisões já tomadas.

## Entregue

- Site Docusaurus 3.10.2 em `site/`, em português do Brasil, publicado em https://titulize.github.io/boleto-docs/.
- 19 ADRs, modelo de ADR, modelo de runbook.
- Diagramas C4 em Mermaid: contexto, containers e módulos do backend. Página de multi-tenancy e auditoria.
- Guias de versões, custos, e commits e releases.
- Container em Amazon Linux 2023 (`docker/docs.Dockerfile`) com Node conferido por sha256. `docker compose up docs` abre `http://localhost:3000/boleto-docs/`.
- Workflow `docs.yml`: build em todo PR, publicação no GitHub Pages a cada push na `main` que altera `site/`.

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| Build de produção | `npm run build` no container | passou, sem links quebrados |
| Servidor de desenvolvimento | `docker compose up docs` e requisições às páginas | 200 nas páginas testadas |
| Publicação | `https://titulize.github.io/boleto-docs/` e `/adr/valkey` | 200 |
| CI | workflows CI e Documentação no commit `7457bce` | verdes |

Não verificado: a renderização visual dos diagramas Mermaid em um navegador.

## Falhas e correções

- O Node não rodava no Amazon Linux por falta da `libatomic`. Pacote adicionado ao Dockerfile.

## Decisões e desvios do plano

- O Docusaurus remove o prefixo numérico das URLs: o ADR 0006 fica em `/adr/valkey`.

## Pendências

- Branch protection na `main` do `boleto-docs` (possível porque o repositório é público).

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Site, ADRs, diagramas, publicação no GitHub Pages |
