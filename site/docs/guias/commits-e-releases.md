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

## Verificação no commit

O `bootstrap install` grava um hook Git `commit-msg` em cada repositório do projeto. No `git commit`, o hook roda o commitlint e recusa a mensagem fora do padrão (Conventional Commits, título e linhas do corpo com até 100 colunas), inclusive nos worktrees. Detalhes, estado no `doctor` e como reaplicar estão no [guia do ambiente](./ambiente-do-dev.md#hook-de-commit-commitlint) e no [ADR 0043](../adr/0043-hook-commit-msg.md).

`git commit --no-verify` pula o hook. O job `Conventional Commits` da CI continua reprovando o PR com mensagem fora do padrão.

Para conferir uma série de commits de uma vez, como a CI faz: `npx commitlint --from origin/main --to HEAD`.

## Releases

Nos repositórios de aplicação, o `release-please` (Task 14) lê os commits, sobe a versão e gera o changelog. No `boleto-docs`, as tags `vX.Y.Z` são criadas manualmente a cada mudança no `versions.toml`.
