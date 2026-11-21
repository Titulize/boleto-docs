---
sidebar_position: 4
title: Compose de desenvolvimento
---

# Compose de desenvolvimento

A infraestrutura local (PostgreSQL, Valkey e Mailpit) roda no Docker Compose, com o `docker-compose.yml` da raiz do `boleto-docs`. Só os comandos padrão do Docker Compose, sem `-f` e sem scripts. O requisito é o mesmo do [ambiente do desenvolvedor](./ambiente-do-dev.md): Docker com Compose. Nenhum comando exige administrador. As decisões estão no [ADR 0022](../adr/0022-compose-unico.md) (e no [ADR 0020](../adr/0020-compose-dev.md), substituído em parte).

## Serviços

| Serviço | Imagem (`versions.toml`) | No host | Para que serve |
|---|---|---|---|
| `postgres` | PostgreSQL 18.7 | `127.0.0.1:5432` | Banco `boleto` |
| `valkey` | Valkey 9.1.4 ([ADR 0006](../adr/0006-valkey.md)) | `127.0.0.1:6379` | Compatível com Redis, com senha |
| `mailpit` | Mailpit 1.34.0 | SMTP `127.0.0.1:1025`, interface `http://localhost:8025` | Captura todo e-mail enviado |
| `docs` (profile `docs`) | Site Docusaurus, build de `docker/docs.Dockerfile` | `http://localhost:3000/boleto-docs/` | Documentação com recarga ao salvar |
| `flyway` (profile `migrations`) | Imagem do `boleto-migrations` (Flyway por JAR, [ADR 0024](../adr/0024-flyway-jar-corretto.md)), build de `../boleto-migrations` | nenhuma | Aplica as migrações uma vez e sai |

As portas ficam só em `127.0.0.1`: outras máquinas da rede não alcançam os serviços.

O banco sobe só com o superusuário e o banco `boleto`. O schema e as roles de migração e de aplicação são do `boleto-migrations`, que o serviço `flyway` aplica sob demanda (ver [Migrações do banco](#migrações-do-banco-profile-migrations)).

## Comandos

Na raiz do `boleto-docs`:

```bash
docker compose up -d --wait   # sobe a infraestrutura e espera ficar saudável
docker compose ps             # estado dos serviços
docker compose logs -f valkey # acompanha o log de um serviço
docker compose down           # para e remove os containers, mantém os dados
docker compose down -v        # reset: apaga também os dados (sem confirmação)
```

Funcionam igual no PowerShell, no Bash e no Zsh.

- `up -d --wait` espera os healthchecks e sai com erro se algum serviço não ficar saudável. Não sobe o site.
- `down` mantém os volumes `boleto-dev_postgres_data` e `boleto-dev_valkey_data`. O próximo `up` volta com os mesmos dados.
- `down -v` apaga esses volumes. É o reset: o próximo `up` cria banco e Valkey vazios. Não apaga imagens nem o `.env`.
- Para abrir o `psql` dentro do container: `docker compose exec postgres psql -U postgres -d boleto`.

### Site de documentação (profile `docs`)

O serviço `docs` fica no profile `docs` para não subir junto com a infraestrutura.

```bash
docker compose up -d --wait docs      # sobe só o site (http://localhost:3000/boleto-docs/)
docker compose --profile docs up -d --wait   # infraestrutura e site juntos
docker compose --profile docs down    # para tudo, inclusive o site
```

Serviço de profile só é parado quando o profile está ativo. `docker compose down` sem `--profile docs` deixa o site rodando.

A primeira subida do site instala as dependências e leva alguns minutos. Para o build de produção (links quebrados falham):

```bash
docker compose run --rm --no-deps docs sh -c "npm ci && npm run build"
```

### Migrações do banco (profile `migrations`)

O serviço `flyway` usa a imagem do repositório `boleto-migrations`, que precisa estar ao lado do `boleto-docs` (`../boleto-migrations`). Ele fica no profile `migrations` para que `docker compose up -d --wait`, `down` e `down -v` continuem tratando só a infraestrutura ([ADR 0027](../adr/0027-migracao-primeiro-passo.md)). A migração é um comando à parte:

```bash
docker compose run --build --rm flyway   # sobe o PostgreSQL se preciso, aplica as migrações e sai
```

- O comando usa `run --rm` e não `up --exit-code-from`: este implica `--abort-on-container-exit` e pararia o PostgreSQL ao fim. O `run` deixa o banco rodando e o container do `flyway` é removido. O código de saída do comando é o do Flyway (`echo $?`).
- O comando espera o PostgreSQL ficar saudável (`depends_on` com `service_healthy`), roda `migrate` e `validate` e sai com o código do Flyway. Qualquer falha (SQL inválido, migração aplicada e depois alterada, senha errada) termina com código diferente de zero.
- Rodar de novo é seguro: sem migração nova, o Flyway não faz nada.
- `docker compose up -d --wait` não executa o `flyway`. `down -v` apaga o banco, e a próxima migração recria o schema.
- A senha da role `boleto_app` (a que o backend usa) vem de `BOLETO_APP_PASSWORD` (padrão `boleto_app_dev`) e é aplicada a cada execução.
- Para ver o schema, criar uma migração e a regra expand/contract, veja [Migrações do banco](./migracoes.md).

## Conectando

Valores padrão do `docker-compose.yml` (também listados no `.env.example`). São só para desenvolvimento local.

| Serviço | Endereço | Credenciais |
|---|---|---|
| PostgreSQL (administrador) | `jdbc:postgresql://localhost:5432/boleto` | `postgres` / `postgres_dev` |
| PostgreSQL (aplicação, depois da migração) | `jdbc:postgresql://localhost:5432/boleto` | `boleto_app` / `boleto_app_dev` (`BOLETO_APP_PASSWORD`) |
| Valkey | `redis://localhost:6379` | senha `valkey_dev` (sem usuário) |
| Mailpit SMTP | `localhost:1025` | sem autenticação |
| Mailpit interface | `http://localhost:8025` | |

## Mudando portas e senhas

Os valores padrão estão no próprio `docker-compose.yml` (por exemplo, `${POSTGRES_PASSWORD:-postgres_dev}`). O `.env` é opcional. Para trocar algum valor, copie o `.env.example` para `.env` na raiz (o arquivo não vai para o git), edite e rode `docker compose up -d --wait` de novo. Variáveis: `POSTGRES_PORT`, `VALKEY_PORT`, `MAILPIT_SMTP_PORT`, `MAILPIT_UI_PORT`, `DOCS_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `VALKEY_PASSWORD` e `BOLETO_APP_PASSWORD`. Uma variável de ambiente do shell com o mesmo nome vence o `.env`.

Usuário e senha do PostgreSQL só valem na criação do volume. Depois de mudá-los, rode `docker compose down -v`.

## De onde vêm as imagens

As imagens (tag e digest) ficam no bloco gerado do próprio `docker-compose.yml`, entre `# >>> platform-versions` e `# <<< platform-versions`. A [sincronização](./versoes.md) escreve o bloco a partir do `versions.toml`, com uma âncora YAML por imagem em `x-images`, e os serviços usam `image: *postgres-image` e equivalentes. Não edite o bloco à mão: o `npm run sync:check` (e a CI) falha se ele divergir do `versions.toml`. Para trocar uma versão, altere o `versions.toml` e rode `npm run sync`.

## Ambiente que já estava rodando

O arquivo mantém `name: boleto-dev`. Os containers (`boleto-dev-postgres-1`, `boleto-dev-valkey-1`, `boleto-dev-mailpit-1`) e os volumes (`boleto-dev_postgres_data`, `boleto-dev_valkey_data`) são os mesmos de antes, então os dados continuam. Quem subiu o ambiente com `compose/dev.ps1` ou `compose/dev.sh` e atualizou para este arquivo só precisa rodar, na raiz, `docker compose up -d --wait`. O Compose recria um container se a configuração dele mudou. Os dados ficam nos volumes e não se perdem na recriação. Não rode `down -v` se quiser mantê-los. O volume `boleto-docs_docs_node_modules` (cache do site, projeto antigo `boleto-docs`) fica sem uso e pode ser removido com `docker volume rm boleto-docs_docs_node_modules`.

Quem usava o `compose/.env` (ignorado pelo git, por isso a pasta `compose/` pode continuar na máquina depois do pull): copie os valores trocados (senhas, portas) para o `.env` da raiz (modelo: `.env.example`), apague a pasta `compose/` e rode `docker compose up -d --wait`. Sem essa cópia, valem os padrões do arquivo (`postgres_dev`, `valkey_dev`, portas 5432, 6379 e 8025). Senha diferente da que o volume já guarda não troca a senha do PostgreSQL existente: use a mesma senha ou `docker compose down -v`.
## Problemas conhecidos

- **Porta ocupada** (por exemplo, um PostgreSQL instalado na máquina): o `up` falha com `port is already allocated` ou `address already in use`. Defina outra porta no `.env` (`POSTGRES_PORT=5433`) e rode o `up` de novo.
- **Limite de pulls dos registros:** as imagens do Valkey e do Mailpit vêm do `docker.io`, e a do PostgreSQL vem do `public.ecr.aws`. Os dois limitam pulls anônimos (o `public.ecr.aws` respondeu `Data limit exceeded` na CI). Se o pull falhar, espere e tente de novo, ou faça `docker login`. A CI usa um cache das imagens para evitar isso ([ADR 0021](../adr/0021-cache-imagens-ci.md)); na máquina do dev, o Docker já guarda as imagens baixadas.
- **Volume do PostgreSQL 18:** o volume é montado em `/var/lib/postgresql`, não em `/var/lib/postgresql/data`. No PostgreSQL 18 os dados ficam em `/var/lib/postgresql/18/docker`.
- **Dois ambientes na mesma máquina:** o nome do projeto é fixo (`boleto-dev`). Para uma segunda cópia (por exemplo, outro clone), use `docker compose -p outro-nome ...` e troque as portas por variáveis de ambiente.

## Observabilidade

O profile `observability` com o Grafana LGTM (`OTEL_LGTM_IMAGE`, já no `versions.env`) entra no Task 11, quando o backend passar a emitir telemetria ([ADR 0014](../adr/0014-observabilidade.md)). Hoje o compose não tem esse serviço.

## Como é testado

| Teste | O que cobre | Onde roda |
|---|---|---|
| `scripts/compose.test.mjs` (`npm test`) | Nome do projeto `boleto-dev`, só o compose da raiz, serviços e profiles `docs` e `migrations` (o `flyway` roda uma vez e espera o banco saudável), toda imagem vem de uma âncora do bloco gerado e tem digest, todo serviço de infraestrutura tem healthcheck, toda porta fica em `127.0.0.1`, toda variável tem valor padrão e consta no `.env.example` com o mesmo valor | Local e CI |
| `scripts/sync-versions.test.mjs` (`npm test`) | O `sync:check` detecta edição manual no bloco gerado do compose e o `sync` corrige | Local e CI |
| Job `Compose de desenvolvimento (Linux)` | `docker compose config`, `up -d --wait` só com a infraestrutura, sondas (`select 1`, `PONG`, `NOAUTH` sem senha, HTTP 200 no Mailpit, portas em `127.0.0.1`), `down` mantém os dados e `down -v` os apaga | CI |

O runner Windows da CI não roda containers Linux, por isso não há job de compose no Windows. A demonstração no Windows com Docker Desktop é feita à mão e registrada no [Task 5](../progresso/task-05-compose-dev.md).
