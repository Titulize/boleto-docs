---
sidebar_position: 1
title: Versões centrais
---

# Versões centrais

O arquivo [`versions.toml`](https://github.com/Titulize/boleto-docs/blob/main/versions.toml) é a única fonte das versões usadas na plataforma.

## Regras

- Toda versão é exata. Não há faixas (`^`, `~`, `*`) nem `latest`.
- Toda imagem Docker tem tag e digest `sha256`.
- Todo download tem URL `https` e `sha256`.
- Cada mudança recebe uma tag `vX.Y.Z` no `boleto-docs`.

## Como os outros repositórios consomem

1. O repositório fixa uma tag do `boleto-docs` (nunca a `main`).
2. O script `sync-versions.mjs` gera os arquivos derivados a partir dessa tag.
3. A CI roda `check` e falha se houver divergência.

O formato do `versions.toml` é próprio porque o Gradle rejeita chaves desconhecidas em um catálogo de versões.

### O que cada repositório recebe

| Repositório (alvo) | Arquivos gerados |
|---|---|
| `boleto-backend` (`backend`) | `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties` (com checksum), `.node-version`, `mise.toml` (Java e Node, o Node para o commitlint), `.platform/versions.env` (imagens, inclusive `MAILPIT_IMAGE` desde a `v0.6.0`, para os testes de e-mail), bloco de `ARG` no `Dockerfile` |
| `boleto-frontend` (`frontend`) | `.node-version`, `mise.toml` (Node), versões dos pacotes no `package.json`, `.platform/versions.env`, bloco de `ARG` no `Dockerfile` |
| `boleto-migrations` (`migrations`) | `.platform/versions.env`, `.platform/flyway-jars.lock` (JARs do Flyway com sha256), `.node-version`, `mise.toml` (Node, para o commitlint), bloco de `ARG` (imagens, Flyway e Squawk) no `Dockerfile`, bloco de imagens (`x-images`, só o PostgreSQL) no `compose.test.yml` |
| `boleto-docs` (`docs`) | `.platform/versions.env` (usado pelo [bootstrap](./ambiente-do-dev.md)), `mise.toml` (Node), bloco de `ARG` em `docker/docs.Dockerfile`, bloco de imagens (`x-images`) no `docker-compose.yml` do [Compose de desenvolvimento](./compose-dev.md), versões em `site/package.json` |

Nos Dockerfiles e no `docker-compose.yml`, o bloco entre `# >>> platform-versions` e `# <<< platform-versions` é gerado. Não edite à mão. O `npm run sync:check` falha se algum bloco divergir do `versions.toml`. Os arquivos que recebem blocos ficam listados no `.platform/lock.json` (`dockerfiles` e `composeFiles`).

### Arquivos da pasta `.platform/` (nos repositórios de aplicação)

| Arquivo | Função |
|---|---|
| `lock.json` | Alvo, tag fixada e sha256 do `versions.toml` daquela tag |
| `versions.toml` | Cópia do arquivo central na tag fixada |
| `sync-versions.mjs` e arquivos de apoio | O script, copiado da mesma tag. Não precisa de `npm install` |
| `versions.env` | Variáveis (imagens com digest, versões) para Compose e scripts |
| `flyway-jars.lock` | Só no alvo `migrations`. Uma linha por JAR do Flyway: sha256, URL do Maven Central e nome do arquivo. O estágio de download do Dockerfile confere cada sha256 |

### Comandos

Rode na raiz do repositório. O script usa só o Node.

```bash
# Configurar um repositório novo (uma vez)
node <boleto-docs>/scripts/sync-versions.mjs init --target backend --tag v0.2.0 --root .

# Regenerar os arquivos derivados
node .platform/sync-versions.mjs sync

# Verificar divergências (CI). Com --remote, confere também a tag no GitHub
node .platform/sync-versions.mjs check --remote

# Trocar para uma tag nova
node .platform/sync-versions.mjs update --tag v0.3.0
```

O `check` falha quando um arquivo gerado foi editado à mão, quando a cópia do `versions.toml` não confere com o sha256 do lock, ou (com `--remote`) quando a tag no GitHub mudou depois de fixada.

No `boleto-docs` os comandos são `npm run sync` e `npm run sync:check`.

### Flyway e Squawk

O Flyway entra como JAR sobre Amazon Corretto headless ([ADR 0024](../adr/0024-flyway-jar-corretto.md)), não pelo CLI oficial. No `versions.toml`, `[tools.flyway]` tem `version`, `main_class` e a tabela `[tools.flyway.jars]`, com `group`, `artifact`, `version` e `sha256` de cada JAR. As variáveis `FLYWAY_URL` e `FLYWAY_SHA256` deixaram de existir. O alvo `migrations` recebe `FLYWAY_VERSION` e `FLYWAY_MAIN_CLASS`. O Squawk (lint de SQL, [ADR 0028](../adr/0028-lint-sql-e-testes.md)) tem `[tools.squawk]` e as variáveis `SQUAWK_VERSION`, `SQUAWK_URL` e `SQUAWK_SHA256`.

O alvo `migrations` foi criado na tag `v0.4.0`, que o `boleto-migrations` fixa (`init --target migrations --tag v0.4.0`). Para atualizar o Flyway: resolva a lista de JARs de novo (`mvn dependency:copy-dependencies` num container descartável, com as exclusões que deixam só o PostgreSQL), confira cada sha256 contra o Maven Central, atualize a tabela e rode `npm run validate`, `npm run sync` e `npm test`. O Renovate não cobre essa tabela.

## Atualizando uma versão

1. Abra um PR no `boleto-docs` alterando o `versions.toml`. O Renovate também abre esses PRs toda segunda-feira.
2. Rode `npm run validate`, `npm run sync` e `npm test`. O `sync` atualiza os arquivos derivados do próprio `boleto-docs`.
3. Depois do merge, crie a tag (`vX.Y.Z`).
4. Nos outros repositórios, rode `node .platform/sync-versions.mjs update --tag vX.Y.Z` e commite o resultado.

Digests de imagens e checksums de downloads exigem revisão manual: confira a origem antes de aprovar.
