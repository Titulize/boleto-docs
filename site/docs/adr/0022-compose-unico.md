---
title: 'ADR 0022: Compose único, só com comandos padrão'
---

# ADR 0022: Compose único, só com comandos padrão

- **Status:** Substituído em parte pelo [ADR 0035](./0035-compose-sobe-a-aplicacao-inteira.md)
- **Data:** 2026-11-21
- **Substitui em parte:** [ADR 0020](./0020-compose-dev.md)

> **Substituído em parte pelo [ADR 0035](./0035-compose-sobe-a-aplicacao-inteira.md):** o `up -d --wait` sem profile deixa de subir só a infraestrutura: ele passa a subir também a migração (`flyway`) e o `backend`, e o `down` os derruba. O `docs` continua no profile `docs`. Continuam valendo o arquivo único, o `name: boleto-dev`, as imagens no bloco gerado, os valores padrão e o uso só de comandos padrão.

## Contexto

O [ADR 0020](./0020-compose-dev.md) separou a infraestrutura (`compose/docker-compose.yml`) do site (`docker-compose.yml` na raiz), passou as imagens por `.platform/versions.env` e criou os atalhos `compose/dev.ps1` e `compose/dev.sh`. O uso exigia o atalho, ou repetir `-f` e dois `--env-file` no `docker compose` direto. O desenvolvedor pediu comandos comuns do Docker Compose, guardados em um `compose.yml`, sem scripts.

## Decisão

- **Um arquivo só:** o `docker-compose.yml` da raiz do `boleto-docs` tem PostgreSQL, Valkey, Mailpit e o site (`docs`). A pasta `compose/`, os atalhos e os verificadores `verify.*` deixam de existir.
- **Comandos:** `docker compose up -d --wait`, `ps`, `logs -f <serviço>`, `down` (mantém os dados) e `down -v` (reset, sem confirmação, como no Docker).
- **Site em profile:** o serviço `docs` tem `profiles: [docs]`. O `up -d --wait` sobe só a infraestrutura. O site sobe com `docker compose --profile docs up -d --wait docs` (ou `docker compose up docs`, que ativa o profile do serviço nomeado). O `docker compose run --rm --no-deps docs ...` do padrão do projeto continua valendo sem mudança.
- **Nome do projeto fixo:** `name: boleto-dev`. Os volumes `boleto-dev_postgres_data` e `boleto-dev_valkey_data` e os nomes dos containers continuam os mesmos, então quem já tem o ambiente rodando não perde dados.
- **Imagens no próprio arquivo, em bloco gerado:** a sincronização grava, entre `# >>> platform-versions` e `# <<< platform-versions`, uma âncora YAML por imagem em `x-images` (`postgres: &postgres-image <imagem>:<tag>@sha256:...`). Os serviços usam `image: *postgres-image`. O bloco pertence ao alvo `docs` do `sync-versions.mjs` (lista `composeFiles` do `.platform/lock.json`, imagens em `composeImages`). O `npm run sync:check`, que roda na CI, falha se o bloco divergir do `versions.toml`.
- **Padrões no arquivo:** credenciais e portas têm valor padrão de desenvolvimento (`${POSTGRES_PASSWORD:-postgres_dev}`). O `.env` na raiz é opcional. O `.env.example` continua como lista das variáveis que podem ser trocadas, e um teste do `npm test` exige que ele e o arquivo tenham os mesmos valores.
- **CI:** o job `Compose de desenvolvimento (Linux)` roda os comandos padrão, sondas inline e o ciclo `down` / `down -v`. O cache das imagens ([ADR 0021](./0021-cache-imagens-ci.md)) segue a mesma chave, porque a lista de imagens com digest não mudou. O job `Compose (Windows PowerShell 5.1)` foi removido: ele só testava o `dev.ps1`.

Continuam valendo do ADR 0020: portas só em `127.0.0.1`, Valkey com senha, volumes nomeados para PostgreSQL e Valkey, Mailpit em memória, healthchecks e o profile `observability` previsto para o Task 11.

## Consequências

- O dev usa só o Docker Compose, nos mesmos comandos em Windows, Linux e macOS. Nada de PowerShell, Bash nem `--env-file`.
- Há uma fonte a menos para manter: dois scripts, três arquivos de teste e um job de CI saem.
- O bloco de imagens é texto gerado dentro de um arquivo escrito à mão. Editar o bloco é erro pego pela CI. O Compose só lê as âncoras, então `docker compose config` mostra as imagens já resolvidas.
- `down -v` apaga os dados sem perguntar. Quem quiser manter os dados usa `down`.
- O `.platform/versions.env` deixa de ser lido pelo Compose. Continua existindo para o bootstrap.
- O `compose/.env` do dev é ignorado pelo git e continua na máquina depois do pull. Ele deixa de valer. Quem trocou senhas ou portas copia os valores para o `.env` da raiz e apaga a pasta `compose/`. O teste `scripts/compose.test.mjs` confere a ausência dos arquivos rastreados, não da pasta, para não falhar nessa máquina.
- O volume `docs_node_modules` passa do projeto `boleto-docs` para o `boleto-dev` (`boleto-dev_docs_node_modules`). É só cache de `npm ci`, refeito na primeira subida do site. O volume antigo (`boleto-docs_docs_node_modules`) fica órfão e pode ser removido com `docker volume rm`.
- O site passa a publicar a porta `3000` só em `127.0.0.1` (antes, em todas as interfaces), como as demais portas. A porta se troca com `DOCS_PORT`.
- Serviço de profile só é parado quando o profile está ativo. Medido: com o site no ar, `docker compose down -v` sem `--profile docs` derruba a infraestrutura, mas deixa o container `docs` e o volume `docs_node_modules`. Para parar tudo, inclusive o site, use `docker compose --profile docs down` (ou `down -v`). O guia traz essa regra.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Manter `compose/` com `include:` ou `-f` | Exige `-f` ou `COMPOSE_FILE` para o comando padrão funcionar |
| Imagens por `${..._IMAGE}` e `.env` gerado pela sincronização | O Compose só lê `.env` da raiz, e o arquivo gerado misturaria com as senhas editáveis do dev. Quem apagasse o `.env` perderia as imagens |
| Tag e digest escritos à mão no compose | Duplica o `versions.toml` e permite divergência |
| Bloco gerado com `image:` em cada serviço | O bloco ficaria espalhado pelo arquivo. A âncora em `x-images` mantém o trecho gerado em um lugar só |
| Manter os atalhos como opção | Decisão do usuário: só Docker Compose |
| Manter o job do Windows PowerShell 5.1 | Sem scripts de compose não há o que testar nele. O runner Windows também não roda containers Linux |
