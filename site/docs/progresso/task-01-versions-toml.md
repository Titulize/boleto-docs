---
sidebar_position: 1
title: 'Task 01: versions.toml central'
---

# Task 01: Repositório `boleto-docs` e `versions.toml` central

- **Situação:** Concluída
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-20
- **Repositórios:** `boleto-docs`

## Objetivo

Criar o repositório de plataforma e o arquivo central de versões, com valores pesquisados e pinados.

## Entregue

- `versions.toml` com Java (Corretto 25.0.5), Node 26.13.1 LTS, Gradle 9.9.2, Flyway CLI 13.13.0, imagens Docker com digest (Amazon Linux 2023, Corretto, PostgreSQL 18.7, Valkey 9.1.4, Mailpit, Grafana LGTM) e bibliotecas do backend e do frontend (Spring Boot 4.1.3, Angular 22.3.0).
- `scripts/validate-versions.mjs`: rejeita versão sem pin, imagem sem digest, download sem sha256 e seções ausentes.
- CI (`.github/workflows/ci.yml`), Renovate (`renovate.json`) e commitlint.
- Tags `v0.1.0` (inicial) e `v0.1.1` (Valkey no lugar do Redis).

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| Validação | `npm run validate` | passou |
| Testes do validador | `npm test` | 8 testes, todos passaram |
| CI | workflow CI nos commits `0ecb582` e `3c1dc26` | verde |

Não verificado: o Renovate não foi instalado na organização, então os PRs automáticos ainda não foram vistos.

## Falhas e correções

- O primeiro `npm test` falhou porque `node --test scripts/` trata a pasta como arquivo. Corrigido para o padrão `scripts/**/*.test.mjs` antes do commit.

## Decisões e desvios do plano

- Redis trocado por Valkey 9.1, a linha oferecida pelo ElastiCache ([ADR 0006](../adr/0006-valkey.md)).
- Validador em Node, uma implementação para os três sistemas.

## Pendências

- Instalar o app do Renovate na organização Titulize.
- Definir a licença do `boleto-docs` (repositório público).

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Versões pesquisadas, `versions.toml`, validador, CI, tag `v0.1.0` |
| 2026-11-20 | Valkey no lugar do Redis, tag `v0.1.1` |
