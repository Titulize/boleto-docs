---
sidebar_position: 3
title: Commits e releases
---

# Commits e releases

Os commits seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/). A CI valida as mensagens de cada PR.

## Formato

```text
<tipo>(<escopo opcional>): <descrição no imperativo>

<corpo opcional>
```

| Tipo | Quando usar |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de defeito |
| `docs` | Só documentação |
| `refactor` | Mudança de código sem alterar comportamento |
| `test` | Testes |
| `build` | Build, Gradle, Docker, dependências |
| `ci` | Pipelines |
| `chore` | Manutenção sem impacto no produto |

Mudança incompatível: `feat!:` ou `BREAKING CHANGE:` no corpo.

## Exemplos

```text
feat(auth): adiciona rotação de refresh token
fix(usuarios): impede convite reutilizado
build(deps): atualiza Gradle para 9.9.2
```

## Releases

Nos repositórios de aplicação, o `release-please` (Task 14) lê os commits, sobe a versão e gera o changelog. No `boleto-docs`, as tags `vX.Y.Z` são criadas manualmente a cada mudança no `versions.toml`.
