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
| `boleto-backend` (`backend`) | `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties` (com checksum), `.platform/versions.env`, bloco de `ARG` no `Dockerfile` |
| `boleto-frontend` (`frontend`) | `.node-version`, versões dos pacotes no `package.json`, `.platform/versions.env`, bloco de `ARG` no `Dockerfile` |
| `boleto-migrations` (`migrations`) | `.platform/versions.env`, bloco de `ARG` (Flyway) no `Dockerfile` |
| `boleto-docs` (`docs`) | `.platform/versions.env`, bloco de `ARG` em `docker/docs.Dockerfile`, versões em `site/package.json` |

Nos Dockerfiles, o bloco entre `# >>> platform-versions` e `# <<< platform-versions` é gerado. Não edite à mão.

### Arquivos da pasta `.platform/` (nos repositórios de aplicação)

| Arquivo | Função |
|---|---|
| `lock.json` | Alvo, tag fixada e sha256 do `versions.toml` daquela tag |
| `versions.toml` | Cópia do arquivo central na tag fixada |
| `sync-versions.mjs` e arquivos de apoio | O script, copiado da mesma tag. Não precisa de `npm install` |
| `versions.env` | Variáveis (imagens com digest, versões) para Compose e scripts |

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

## Atualizando uma versão

1. Abra um PR no `boleto-docs` alterando o `versions.toml`. O Renovate também abre esses PRs toda segunda-feira.
2. Rode `npm run validate`, `npm run sync` e `npm test`. O `sync` atualiza os arquivos derivados do próprio `boleto-docs`.
3. Depois do merge, crie a tag (`vX.Y.Z`).
4. Nos outros repositórios, rode `node .platform/sync-versions.mjs update --tag vX.Y.Z` e commite o resultado.

Digests de imagens e checksums de downloads exigem revisão manual: confira a origem antes de aprovar.
