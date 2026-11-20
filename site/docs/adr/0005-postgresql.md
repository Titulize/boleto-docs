---
title: 'ADR 0005: PostgreSQL como banco relacional'
---

# ADR 0005: PostgreSQL como banco relacional

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O sistema é financeiro e multiempresa. Precisa de integridade transacional, isolamento forte entre empresas e migrações seguras. A migração roda em um processo separado do backend.

## Decisão

PostgreSQL 18 como banco único de dados transacionais e de auditoria. Na AWS: RDS ou Aurora Serverless v2.

## Consequências

- Row-Level Security reforça o isolamento por `tenant_id` no banco (ver [ADR 0008](./0008-multitenancy.md)).
- DDL transacional: uma migração Flyway que falha no meio é revertida por inteiro.
- JSONB permite guardar valores de auditoria de forma flexível quando for útil.
- A imagem local é a oficial do PostgreSQL. Na AWS será serviço gerenciado.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| MySQL | Sem RLS nativo e sem DDL transacional |
| PostgreSQL 19 | Acabou de sair (19.0). Adotamos a 18, mais madura, e avaliamos a 19 depois |
