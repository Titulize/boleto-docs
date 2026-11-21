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
| [0022](./0022-compose-unico.md) | Compose único, só com comandos padrão | Aceito |
