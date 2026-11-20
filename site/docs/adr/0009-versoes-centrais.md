---
title: 'ADR 0009: Versões centrais em versions.toml'
---

# ADR 0009: Versões centrais em `versions.toml`

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Quatro repositórios usam as mesmas ferramentas e imagens. Versões soltas geram builds diferentes entre máquinas, CI e produção.

## Decisão

Um arquivo `versions.toml` no `boleto-docs` concentra todas as versões, com valores exatos, digests de imagens e checksums de downloads. Cada mudança recebe uma tag `vX.Y.Z`. Os demais repositórios fixam uma tag e geram os arquivos derivados por script, e a CI falha se houver divergência. O Renovate abre os PRs de atualização.

O formato é próprio: o Gradle rejeita chaves desconhecidas em um catálogo de versões, então o `libs.versions.toml` é gerado a partir do arquivo central.

## Consequências

- Uma única revisão de segurança por atualização.
- Cada repositório precisa rodar a sincronização ao trocar de tag.
- A validação do arquivo (`npm run validate`) roda na CI do `boleto-docs`.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Cada repositório com suas versões | Diverge com o tempo e não há visão única |
| Catálogo do Gradle como fonte | Serve só ao backend |
| Ler a branch `main` do repositório central | Quebra a reprodutibilidade dos builds |
