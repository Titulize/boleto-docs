---
title: 'ADR 0034: Serviço backend no Compose'
---
# ADR 0034: Serviço `backend` no Compose
- **Status:** Substituído em parte pelo [ADR 0035](./0035-compose-sobe-a-aplicacao-inteira.md)
- **Data:** 2026-11-21
> **Substituído em parte pelo [ADR 0035](./0035-compose-sobe-a-aplicacao-inteira.md):** o `backend` e o `flyway` deixam de usar profiles (`backend` e `migrations`) e sobem no `docker compose up -d` padrão, e `docker compose down` os derruba. O comando `--profile backend up -d --build --wait` deixa de existir. Continuam valendo o build por `BACKEND_CONTEXT` e `MIGRATIONS_CONTEXT`, o `depends_on`, a porta em `127.0.0.1`, o healthcheck e as variáveis.

## Contexto
O [ADR 0022](./0022-compose-unico.md) fixou um Compose único, só com comandos padrão, e o [ADR 0027](./0027-migracao-primeiro-passo.md) fez da migração o primeiro passo do deploy. O backend precisa subir no mesmo Compose do dev sem mudar o que `docker compose up -d --wait` faz.
## Decisão
- Serviço `backend` com `profiles: [backend]`, `build.context: ${BACKEND_CONTEXT:-../boleto-backend}` e `image: boleto-backend:dev`. A imagem é construída aqui, por isso não usa uma âncora do bloco gerado `x-images` (as imagens base Corretto vêm do `Dockerfile` do backend, sincronizado pelo `versions.toml`).
- `depends_on`: `postgres` com `service_healthy` e `flyway` com `service_completed_successfully`. O backend não depende do Valkey.
- O serviço `flyway` passa a `profiles: [migrations, backend]`, e seu contexto vira `${MIGRATIONS_CONTEXT:-../boleto-migrations}`. Assim `--profile backend` puxa o banco e a migração sozinho.
- Porta `127.0.0.1:${BACKEND_PORT:-8080}:8080`. Healthcheck por `curl -fsS http://localhost:8080/actuator/health`, com `start_period` de 60 s (a imagem Corretto headless tem `curl`).
- Ambiente: `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME=boleto_app`, `SPRING_DATASOURCE_PASSWORD=${BOLETO_APP_PASSWORD:-boleto_app_dev}` e as duas variáveis do springdoc ligadas ([ADR 0032](./0032-esqueleto-do-backend.md)).
- Comando: `docker compose --profile backend up -d --build --wait`. Sem profile, `up -d --wait` sobe só PostgreSQL, Valkey e Mailpit.
- As variáveis de contexto existem porque, em um worktree do git, `../boleto-backend` não resolve.
## Consequências
- Só comandos padrão, como no ADR 0022. `--wait` aceita o `flyway` que sai com 0 (verificado na demonstração).
- O `flyway` roda de novo a cada `up` do profile `backend`. A migração é idempotente.
- `down` sem `--profile backend` não para o backend: use `docker compose --profile backend down`.
- `scripts/compose.test.mjs` cobre o profile, a porta em `127.0.0.1` e as dependências. O job de Compose da CI continua subindo só a infraestrutura.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Backend sem profile | `up -d --wait` passaria a construir o backend e exigir o `boleto-backend` ao lado |
| Rodar o `flyway` à parte antes do backend | Dois comandos, e o dev esquece o primeiro. O `depends_on` garante a ordem |
| Imagem do backend por âncora do `x-images` | A imagem não vem de um registro. A fonte da versão é o `Dockerfile` do backend |
| Script de atalho | Contraria o ADR 0022 |