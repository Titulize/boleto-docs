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
2. Um script de sincronização gera os arquivos derivados: `libs.versions.toml` do Gradle, argumentos de build do Docker e pins do frontend.
3. A CI roda o script em modo `--check` e falha se houver divergência.

O formato do `versions.toml` é próprio porque o Gradle rejeita chaves desconhecidas em um catálogo de versões.

## Atualizando uma versão

1. Abra um PR no `boleto-docs` alterando o `versions.toml`. O Renovate também abre esses PRs toda segunda-feira.
2. Rode `npm run validate` e `npm test`.
3. Depois do merge, crie a tag (`vX.Y.Z`).
4. Nos outros repositórios, atualize a tag fixada e rode a sincronização.

Digests de imagens e checksums de downloads exigem revisão manual: confira a origem antes de aprovar.
