---
title: 'ADR 0001: Polirepo com 4 repositórios'
---

# ADR 0001: Polirepo com 4 repositórios

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O projeto tem backend, frontend, migrações de banco e documentação. Os ciclos de release e os acessos podem divergir. As migrações serão executadas por um processo separado (possivelmente uma Lambda).

## Decisão

Quatro repositórios na organização Titulize: `boleto-backend`, `boleto-frontend`, `boleto-migrations` e `boleto-docs`. O `boleto-docs` também guarda o `versions.toml`, o Docker Compose de desenvolvimento e os scripts de bootstrap.

## Consequências

- Cada repositório tem pipeline, versão e permissões próprias.
- Mudanças que cruzam repositórios exigem PRs coordenados. O `versions.toml` central reduz a divergência.
- O ambiente local precisa clonar os quatro repositórios. O script de bootstrap faz isso.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Monorepo | Preferência explícita por separação, e as migrações têm ciclo de execução próprio |
| Três repositórios, com a documentação dentro do backend | A documentação e as versões servem a todos, então ficam fora de um repositório de aplicação |
