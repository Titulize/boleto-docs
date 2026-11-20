---
title: 'ADR 0008: Multi-tenancy com tenant_id e RLS'
---

# ADR 0008: Multi-tenancy com `tenant_id` e RLS

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Há empresas gestoras, empresas clientes e usuários por empresa. Os dados de uma empresa gestora nunca podem aparecer para outra.

## Decisão

Um único banco e schema. Toda tabela de negócio tem `tenant_id` (a empresa gestora). O isolamento tem duas camadas:

1. `@TenantId` do Hibernate na aplicação.
2. Row-Level Security no PostgreSQL, ativado por `SET LOCAL app.tenant_id` a cada transação.

O backend usa uma role sem `BYPASSRLS` e sem DDL.

## Consequências

- Simples e barato de operar, com uma única migração para todos os tenants.
- Um bug na aplicação não vaza dados, porque o banco também filtra.
- Testes de integração provam o isolamento, inclusive com o filtro do Hibernate desligado.
- Consultas administrativas entre tenants exigem uma role e um caminho explícitos.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Schema por empresa gestora | Migrações e conexões mais complexas |
| Banco por empresa gestora | Custo e operação altos |
| Instalação por empresa | Sem multi-tenancy, contrário ao modelo de negócio |
