---
title: 'ADR 0017: Conventional Commits e release-please'
---

# ADR 0017: Conventional Commits e release-please

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Com quatro repositórios, é preciso um padrão simples para o histórico, as versões e os changelogs.

## Decisão

Conventional Commits, validados na CI com commitlint. Nos repositórios de aplicação, o `release-please` calcula a versão e gera o changelog a partir dos commits. No `boleto-docs`, as tags do `versions.toml` são criadas manualmente.

Detalhes em [Commits e releases](../guias/commits-e-releases.md).

## Consequências

- Histórico legível e versionamento automático.
- Mensagens fora do padrão bloqueiam o PR.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Mensagens livres | Sem changelog nem versão automáticos |
| semantic-release | O release-please funciona por PR de release, que é mais fácil de revisar |
