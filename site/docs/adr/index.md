---
sidebar_position: 0
title: Decisões de arquitetura (ADRs)
---

# Decisões de arquitetura

Cada decisão relevante vira um ADR (Architecture Decision Record): contexto, decisão, consequências e alternativas. Um ADR aceito não é editado. Para mudar uma decisão, crie um novo ADR e marque o antigo como substituído.

Para propor uma decisão, copie o [modelo](./0000-modelo.md).

| ADR | Decisão | Status |
|---|---|---|
| [0001](./0001-polirepo.md) | Polirepo com 4 repositórios | Aceito |
| [0002](./0002-backend-spring-java-gradle.md) | Backend com Spring Boot, Java 25 e Gradle | Aceito |
| [0003](./0003-monolito-modular.md) | Monólito modular por funcionalidade | Aceito |
| [0004](./0004-frontend-angular.md) | Frontend com Angular e Angular Material | Aceito |
| [0005](./0005-postgresql.md) | PostgreSQL como banco relacional | Aceito |
| [0006](./0006-valkey.md) | Valkey para cache, sessão e rate limit | Aceito |
| [0007](./0007-auditoria-envers.md) | Auditoria com Hibernate Envers | Aceito |
| [0008](./0008-multitenancy.md) | Multi-tenancy com `tenant_id` e RLS | Aceito |
| [0009](./0009-versoes-centrais.md) | Versões centrais em `versions.toml` | Aceito |
| [0010](./0010-imagens-amazon-linux.md) | Imagens Amazon Linux 2023 pinadas por digest | Aceito |
| [0011](./0011-ambiente-do-dev.md) | Ambiente do desenvolvedor | Aceito |
| [0012](./0012-autenticacao.md) | Autenticação com JWT e convite por e-mail | Aceito |
| [0013](./0013-rate-limiting.md) | Rate limiting com Bucket4j | Aceito |
| [0014](./0014-observabilidade.md) | Observabilidade com OpenTelemetry | Aceito |
| [0015](./0015-lgpd.md) | Proteção de dados pessoais (LGPD) | Aceito |
| [0016](./0016-supply-chain.md) | Cadeia de suprimentos e assinatura de imagens | Aceito |
| [0017](./0017-conventional-commits.md) | Conventional Commits e release-please | Aceito |
| [0018](./0018-custo-minimo.md) | Custo mínimo e repositório de documentação público | Aceito |
| [0019](./0019-docusaurus.md) | Documentação viva com Docusaurus | Aceito |
| [0020](./0020-compose-dev.md) | Compose de desenvolvimento | Substituído em parte pelo 0022 |
| [0021](./0021-cache-imagens-ci.md) | Cache das imagens Docker na CI | Aceito |
| [0022](./0022-compose-unico.md) | Compose único, só com comandos padrão | Substituído em parte pelo 0035 |
| [0023](./0023-primeira-main-boleto-migrations.md) | Primeira `main` do `boleto-migrations` por exceção | Aceito |
| [0024](./0024-flyway-jar-corretto.md) | Flyway pelo JAR sobre Amazon Corretto headless | Aceito |
| [0025](./0025-modelo-de-dados-v1.md) | Modelo de dados da V1 | Aceito |
| [0026](./0026-roles-e-rls.md) | Roles do banco e RLS forçado | Aceito |
| [0027](./0027-migracao-primeiro-passo.md) | A migração é o primeiro passo do deploy | Substituído em parte pelo 0035 |
| [0028](./0028-lint-sql-e-testes.md) | Lint de SQL com Squawk e testes em PostgreSQL real | Aceito |
| [0029](./0029-permissao-por-tela.md) | Permissão por tela | Aceito |
| [0030](./0030-manutencao-de-dados-e-origem-do-tenant.md) | Manutenção de dados pela dona das tabelas e origem do tenant | Aceito |
| [0031](./0031-primeira-main-boleto-backend.md) | Primeira `main` do `boleto-backend` por exceção | Aceito |
| [0032](./0032-esqueleto-do-backend.md) | Esqueleto do backend | Aceito |
| [0033](./0033-wrapper-qualidade-e-ci-do-backend.md) | Wrapper, qualidade e CI do backend | Substituído em parte pelo 0036 |
| [0034](./0034-servico-backend-no-compose.md) | Serviço `backend` no Compose | Substituído em parte pelo 0035 |
| [0035](./0035-compose-sobe-a-aplicacao-inteira.md) | O Compose sobe a aplicação inteira no `up` padrão | Aceito |
| [0036](./0036-schema-real-nos-testes-do-backend.md) | Schema real do `boleto-migrations` nos testes do backend | Aceito |
| [0037](./0037-contexto-de-tenant-por-transacao.md) | Contexto de tenant e `app.tenant_id` por transação | Aceito |
| [0038](./0038-auditoria-com-envers.md) | Auditoria com Envers, revisão customizada e diff | Aceito |
| [0039](./0039-auditoria-do-catalogo-tela.md) | Auditoria do catálogo `tela` | Aceito |
| [0040](./0040-problem-details-e-catalogo-de-erros.md) | Problem Details e catálogo de erros | Aceito |
| [0041](./0041-logs-json-com-traceid.md) | Logs JSON com `traceId` | Aceito |
| [0042](./0042-v2-tenant-da-auditoria-da-empresa.md) | V2: tenant da auditoria da empresa gestora | Aceito |
| [0043](./0043-hook-commit-msg.md) | Hook `commit-msg` com commitlint, instalado pelo bootstrap | Aceito |
| [0044](./0044-jwt-es256-e-chave.md) | JWT com ES256 e origem da chave | Aceito |
| [0045](./0045-claims-tempos-e-sessao-diaria.md) | Claims, tempos de vida e sessão diária | Aceito |
| [0046](./0046-refresh-e-blacklist-no-valkey.md) | Refresh token e blacklist no Valkey | Aceito |
| [0047](./0047-rate-limiting-e-bloqueio-de-conta.md) | Limite de requisições e bloqueio de conta | Aceito |
| [0048](./0048-permissoes-por-anotacao-e-assumir-empresa.md) | Permissões por anotação e assumir empresa | Aceito |
| [0049](./0049-administrador-inicial.md) | Administrador inicial | Aceito |
| [0050](./0050-contexto-de-tenant-jwt-e-threads.md) | Contexto de tenant, JWT e threads | Aceito |
