---
title: 'ADR 0020: Compose de desenvolvimento'
---

# ADR 0020: Compose de desenvolvimento

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O desenvolvedor precisa de PostgreSQL, Valkey e Mailpit locais, com as mesmas versões do `versions.toml` ([ADR 0009](./0009-versoes-centrais.md)) e só com Docker e Compose instalados ([ADR 0011](./0011-ambiente-do-dev.md)). O `docker-compose.yml` da raiz do `boleto-docs` já sobe o site de documentação, com build próprio e bind mount de `site/`.

## Decisão

- A infraestrutura fica em `compose/docker-compose.yml`, projeto Compose `boleto-dev`, separado do projeto `boleto-docs` do site.
- O arquivo não tem tag nem digest. As imagens vêm de `${..._IMAGE}` do `.platform/versions.env`. Os atalhos passam esse arquivo e o `compose/.env` como `--env-file`.
- Atalhos `compose/dev.ps1` (PowerShell 7 e 5.1) e `compose/dev.sh` (Bash), com `up`, `down`, `reset`, `ps` e `logs`. Sem Node nem outra ferramenta além do Docker.
- Portas ligadas só a `127.0.0.1`, configuráveis no `compose/.env`.
- Valkey com senha desde o início, como no ElastiCache.
- Volumes nomeados para PostgreSQL e Valkey. O Mailpit guarda os e-mails só em memória.
- O `reset` apaga os volumes do projeto e pede confirmação. Fora de terminal interativo, só roda com `-Yes` / `--yes`.
- O profile `observability` (Grafana LGTM, [ADR 0014](./0014-observabilidade.md)) fica previsto para o Task 11.

## Consequências

- Os dois projetos Compose não colidem em nomes de containers e volumes, e `docker compose up docs` continua igual.
- Trocar uma versão de imagem é só mudar o `versions.toml` e sincronizar. Um teste do `npm test` falha se alguém escrever imagem à mão ou publicar porta fora de `127.0.0.1`.
- Quem chamar o `docker compose` direto precisa repetir os dois `--env-file`.
- Há dois scripts com a mesma interface para manter, como no bootstrap.
- As senhas de desenvolvimento ficam no `compose/.env.example`, público. Elas só valem em loopback.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Um compose único na raiz, com o site e a infraestrutura | Mistura build do site com serviços de runtime. `docker compose down -v` do site apagaria o banco |
| Imagem e tag escritas no compose | Duplica o `versions.toml` e permite divergência |
| Redis | Substituído pelo Valkey ([ADR 0006](./0006-valkey.md)) |
| `curl` nos healthchecks | A imagem do Mailpit não tem shell nem `curl`. O binário tem `readyz` |
| Portas em `0.0.0.0` | Expõe banco e Valkey com senha conhecida na rede local |
| Atalhos em Node (`npm run dev:up`) | Exige Node antes do bootstrap. O requisito mínimo é só Docker, Compose e Git |
