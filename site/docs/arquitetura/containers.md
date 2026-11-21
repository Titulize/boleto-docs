---
sidebar_position: 2
title: Containers (C4 nível 2)
---

# Containers

```mermaid
flowchart LR
  user["Usuário"]

  subgraph plataforma["Plataforma de Boletos"]
    fe["boleto-frontend<br/>Angular + nginx"]
    be["boleto-backend<br/>Spring Boot, Java 25"]
    mg["boleto-migrations<br/>Flyway, execução única"]
    pg[("PostgreSQL<br/>dados, auditoria")]
    vk[("Valkey<br/>refresh token, blacklist, rate limit")]
  end

  mail["Mailpit (dev) / SES (AWS)"]
  otel["OpenTelemetry<br/>Grafana LGTM (dev) / CloudWatch (AWS)"]

  user --> fe
  fe -->|REST + JWT| be
  be --> pg
  be --> vk
  be -->|SMTP| mail
  be -.->|traces, métricas, logs| otel
  mg -->|DDL com role de migração| pg
```

## Responsabilidades

| Container | Responsabilidade |
|---|---|
| `boleto-frontend` | Interface do usuário. O cliente da API é gerado a partir do OpenAPI do backend |
| `boleto-backend` | Regras de negócio, autenticação, auditoria e API REST |
| `boleto-migrations` | Todo o schema do banco (tabelas, auditoria do Envers, políticas RLS, roles) |
| PostgreSQL | Dados transacionais e trilha de auditoria |
| Valkey | Refresh tokens, blacklist de logout e contadores de rate limit |
| Mailpit (só desenvolvimento) | Recebe por SMTP os e-mails enviados pelo backend e os mostra numa interface web |

## Papéis de banco de dados

O backend conecta com uma role sem permissão de DDL e sem `BYPASSRLS`. Só o `boleto-migrations` usa a role de migração. Assim uma falha na aplicação não consegue alterar o schema nem contornar o isolamento entre empresas.

## Ambientes

| Ambiente | PostgreSQL e Valkey | E-mail | Observabilidade |
|---|---|---|---|
| Desenvolvimento | Containers no Docker Compose (`docker-compose.yml` na raiz do `boleto-docs`, portas só em `127.0.0.1`, ver [Compose de desenvolvimento](../guias/compose-dev.md)) | Mailpit | Grafana LGTM (profile opcional, Task 11) |
| AWS (futuro) | RDS ou Aurora Serverless e ElastiCache for Valkey | Amazon SES | CloudWatch e X-Ray |
