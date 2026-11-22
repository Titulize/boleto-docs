---
title: 'ADR 0039: Auditoria do catálogo tela'
---

# ADR 0039: Auditoria do catálogo `tela`

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

O catálogo `tela` não tem `tenant_id` e a V1 não o audita. Ele muda por migração (registrada no `flyway_schema_history`) e, depois, pela tela "Cadastro de Telas", que altera nome, menu e ordem só com origem na plataforma ([ADR 0029](./0029-permissao-por-tela.md)). O [ADR 0025](./0025-modelo-de-dados-v1.md) e o [ADR 0029](./0029-permissao-por-tela.md) deixaram ao Task 8 decidir se a reorganização é auditada.

## Decisão

- **Auditar** nome, menu e ordem com Envers, numa tabela `tela_aud`, porque a reorganização afeta todas as empresas e o `flyway_schema_history` só cobre migrações.
- Como `tela` não tem tenant, a `tela_aud` recebe `tenant_id` por um gatilho do mesmo tipo do [ADR 0042](./0042-v2-tenant-da-auditoria-da-empresa.md), a partir de `tenant_atual()`.
- **A tabela e a entidade `Tela` nascem juntas, na tarefa que construir a tela "Cadastro de Telas".** Este task não cria tabela sem entidade (YAGNI), então nada mudou no schema nem no backend por esta decisão.

## Consequências

- Hoje o catálogo continua sem auditoria de reorganização, e isso é pendência herdada: a migração e a entidade `Tela` ficam para a tarefa do Cadastro de Telas.
- Essa tarefa precisa de uma migração nova (expand) com `tela_aud` e o gatilho, e de teste que prove a revisão com o `tenant_id` da plataforma.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Não auditar `tela` | A reorganização afeta todas as empresas e ficaria sem rastro de quem alterou |
| Criar `tela_aud` agora | Tabela sem entidade nem teste que a exercite |
| Registrar só em log | O log não tem o contrato de revisão (usuário, tenant, valores anterior e novo) |
