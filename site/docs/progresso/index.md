---
sidebar_position: 0
title: Progresso
---

# Progresso da Fase 1

Fundação da plataforma e módulo de Login. Cada tarefa tem um registro com o que foi entregue, como foi verificado, falhas e pendências. Os registros seguem o [modelo](./modelo.md) e são atualizados a cada avanço, conforme o [padrão do projeto](../guias/padrao-do-projeto.md#atualização-da-documentação).

| Task | Título | Situação | Última atualização |
|---|---|---|---|
| [01](./task-01-versions-toml.md) | Repositório `boleto-docs` e `versions.toml` central | Concluída | 2026-11-20 |
| [02](./task-02-docusaurus.md) | Site de documentação viva (Docusaurus) | Concluída | 2026-11-20 |
| [03](./task-03-sincronizacao.md) | Sincronização de versões | Concluída | 2026-11-20 |
| [04](./task-04-bootstrap.md) | Scripts de bootstrap do ambiente do dev | Concluída | 2026-11-20 |
| [05](./task-05-compose-dev.md) | Compose de desenvolvimento (infraestrutura) | Concluída | 2026-11-22 |
| [06](./task-06-boleto-migrations.md) | Repositório `boleto-migrations` (Flyway) | Concluída | 2026-11-22 |
| [07](./task-07-esqueleto-backend.md) | Esqueleto do backend | Concluída | 2026-11-22 |
| [08](./task-08-base-multitenant-auditoria.md) | Base multi-tenant e auditoria | Concluída | 2026-11-22 |
| [M1](./melhoria-hook-commit-msg.md) | Hook `commit-msg` com commitlint (melhoria de processo) | Em andamento | 2026-11-22 |
| [09](./task-09-autenticacao-autorizacao.md) | Autenticação e autorização | Concluída | 2026-11-23 |
| [10](./task-10-convite-e-recuperacao-de-senha.md) | Convite de usuário e "esqueci minha senha" | Em andamento | 2026-11-24 |
| 11 | Observabilidade local | Não iniciada | |
| 12 | Esqueleto do frontend | Não iniciada | |
| 13 | Telas de Login | Não iniciada | |
| 14 | CI/CD e cadeia de suprimentos | Não iniciada | |
| 15 | Documentação final e validação do onboarding | Não iniciada | |

**Nota (2026-11-22):** o `docker compose up -d` passou a subir a aplicação inteira (infraestrutura, migração e backend), sem profile ([ADR 0035](../adr/0035-compose-sobe-a-aplicacao-inteira.md)). As notas posteriores estão nos registros dos Tasks [5](./task-05-compose-dev.md), [6](./task-06-boleto-migrations.md) e [7](./task-07-esqueleto-backend.md).

**Nota (2026-11-24):** o Task 10 entregou o convite e o "esqueci minha senha" no backend, a V3 no `boleto-migrations` e os [ADR 0051](../adr/0051-tokens-de-convite-e-recuperacao-de-senha.md) a [0056](../adr/0056-v3-cpf-do-usuario.md). O registro está [em andamento](./task-10-convite-e-recuperacao-de-senha.md).

**Nota (2026-11-22):** o Task 8 entregou a base multi-tenant e a auditoria no backend, a V2 no `boleto-migrations` e os [ADR 0036](../adr/0036-schema-real-nos-testes-do-backend.md) a [0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md). As pendências dos Tasks 6 e 7 que dependiam dele foram fechadas nos registros respectivos.
