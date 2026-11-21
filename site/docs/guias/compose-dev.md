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
| `flyway` (profiles `migrations` e `backend`) | Imagem do `boleto-migrations` (Flyway por JAR, [ADR 0024](../adr/0024-flyway-jar-corretto.md)), build de `MIGRATIONS_CONTEXT` (padrão `../boleto-migrations`) | nenhuma | Aplica as migrações uma vez e sai |
| `backend` (profile `backend`) | API Spring Boot, build de `BACKEND_CONTEXT` (padrão `../boleto-backend`), imagem `boleto-backend:dev` | `http://localhost:8080` (`BACKEND_PORT`) | Esqueleto do backend com health e Swagger ([ADR 0034](../adr/0034-servico-backend-no-compose.md)) |

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

### Backend (profile `backend`)
O serviço `backend` constrói a imagem do repositório `boleto-backend` (ao lado do `boleto-docs`, em `../boleto-backend`). Ele fica no profile `backend` e puxa sozinho o PostgreSQL e o `flyway`: só sobe depois do banco saudável e da migração concluída com sucesso ([ADR 0027](../adr/0027-migracao-primeiro-passo.md) e [ADR 0034](../adr/0034-servico-backend-no-compose.md)). Sem o profile, `up -d --wait`, `down` e `down -v` continuam tratando só a infraestrutura.
```bash
docker compose --profile backend up -d --build --wait   # constrói, migra, sobe e espera o backend ficar saudável
docker compose --profile backend ps
docker compose --profile backend logs -f backend
docker compose --profile backend down                   # remove os containers, inclusive o backend, e mantém os dados
```
- Endereços (porta padrão 8080, `BACKEND_PORT` troca): `http://localhost:8080/actuator/health`, `http://localhost:8080/swagger-ui.html` (redireciona para `/swagger-ui/index.html`) e `http://localhost:8080/v3/api-docs`. `/swagger-ui` sem a extensão responde 404.
- O health mostra `status` e `components` (`db`, `diskSpace`, `ping`, liveness e readiness), sem `details`. O `db` fica `UP` só se a conexão como `boleto_app` funcionar.
- O Swagger só existe porque o Compose liga `SPRINGDOC_API_DOCS_ENABLED` e `SPRINGDOC_SWAGGER_UI_ENABLED`. A imagem sem essas variáveis não o serve.
- O processo roda com o usuário `10001`: `docker compose --profile backend exec backend id -u`.
- O `flyway` roda de novo a cada `up` do profile. A migração é idempotente. O `--wait` aceita o `flyway` que termina com código 0.
- O backend não depende do Valkey. O Valkey sobe junto porque faz parte da infraestrutura, mas o backend só o usa a partir do Task 9.

**Em worktree do git** o caminho `../boleto-backend` não resolve. Aponte os contextos para os repositórios, no `.env` ou no shell:
```powershell
$env:BACKEND_CONTEXT = 'C:/caminho/boleto-backend'          # ou o worktree do backend
$env:MIGRATIONS_CONTEXT = 'C:/caminho/boleto-migrations'
docker compose --profile backend up -d --build --wait
```
**Sem tocar no ambiente que já roda** (outro nome de projeto e outras portas, como na demonstração do [Task 7](../progresso/task-07-esqueleto-backend.md)):
```powershell
$env:POSTGRES_PORT = '25434'; $env:BACKEND_PORT = '18080'; $env:VALKEY_PORT = '26380'
$env:MAILPIT_SMTP_PORT = '21026'; $env:MAILPIT_UI_PORT = '28026'
docker compose -p boleto-demo --profile backend up -d --build --wait
docker compose -p boleto-demo --profile backend down -v --remove-orphans   # apaga só este ambiente
```
Para rodar o backend fora do Compose (`./gradlew bootRun`) contra o PostgreSQL deste Compose, veja o README do `boleto-backend`: ele usa `POSTGRES_PORT` com o profile `dev`.
## Conectando

Valores padrão do `docker-compose.yml` (também listados no `.env.example`). São só para desenvolvimento local.

| Serviço | Endereço | Credenciais |
|---|---|---|
| PostgreSQL (administrador) | `jdbc:postgresql://localhost:5432/boleto` | `postgres` / `postgres_dev` |
| PostgreSQL (aplicação, depois da migração) | `jdbc:postgresql://localhost:5432/boleto` | `boleto_app` / `boleto_app_dev` (`BOLETO_APP_PASSWORD`) |
| Backend (profile `backend`) | `http://localhost:8080/actuator/health` e `http://localhost:8080/swagger-ui.html` | sem autenticação (Task 9) |
| Valkey | `redis://localhost:6379` | senha `valkey_dev` (sem usuário) |
| Mailpit SMTP | `localhost:1025` | sem autenticação |
| Mailpit interface | `http://localhost:8025` | |

## Mudando portas e senhas

Os valores padrão estão no próprio `docker-compose.yml` (por exemplo, `${POSTGRES_PASSWORD:-postgres_dev}`). O `.env` é opcional. Para trocar algum valor, copie o `.env.example` para `.env` na raiz (o arquivo não vai para o git), edite e rode `docker compose up -d --wait` de novo. Variáveis: `POSTGRES_PORT`, `VALKEY_PORT`, `MAILPIT_SMTP_PORT`, `MAILPIT_UI_PORT`, `DOCS_PORT`, `BACKEND_PORT`, `BACKEND_CONTEXT`, `MIGRATIONS_CONTEXT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `VALKEY_PASSWORD` e `BOLETO_APP_PASSWORD`. Uma variável de ambiente do shell com o mesmo nome vence o `.env`.

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
- **`/swagger-ui` dá 404:** o endereço é `/swagger-ui.html` ou `/swagger-ui/index.html`.
- **Backend não fica saudável:** veja `docker compose --profile backend logs backend`. Causas prováveis: senha de `boleto_app` diferente da gravada no banco (o `flyway` a regrava a cada `up` do profile) ou migração que falhou (`docker compose --profile backend logs flyway`).

## Observabilidade

O profile `observability` com o Grafana LGTM (`OTEL_LGTM_IMAGE`, já no `versions.env`) entra no Task 11, quando o backend passar a emitir telemetria ([ADR 0014](../adr/0014-observabilidade.md)). Hoje o compose não tem esse serviço.

## Como é testado

| Teste | O que cobre | Onde roda |
|---|---|---|
| `scripts/compose.test.mjs` (`npm test`) | Nome do projeto `boleto-dev`, só o compose da raiz, serviços e profiles `docs`, `migrations` e `backend` (o `flyway` roda uma vez e espera o banco saudável; o `backend` espera o banco saudável e o `flyway` concluído, publica só em `127.0.0.1` e não depende do Valkey), toda imagem vem de uma âncora do bloco gerado e tem digest, todo serviço de infraestrutura tem healthcheck, toda porta fica em `127.0.0.1`, toda variável tem valor padrão e consta no `.env.example` com o mesmo valor | Local e CI |
| `scripts/sync-versions.test.mjs` (`npm test`) | O `sync:check` detecta edição manual no bloco gerado do compose e o `sync` corrige | Local e CI |
| Job `Compose de desenvolvimento (Linux)` | `docker compose config`, `up -d --wait` só com a infraestrutura (o profile `backend` não sobe na CI: o build e a CI do backend são do `boleto-backend`), sondas (`select 1`, `PONG`, `NOAUTH` sem senha, HTTP 200 no Mailpit, portas em `127.0.0.1`), `down` mantém os dados e `down -v` os apaga | CI |

O runner Windows da CI não roda containers Linux, por isso não há job de compose no Windows. A demonstração no Windows com Docker Desktop é feita à mão e registrada no [Task 5](../progresso/task-05-compose-dev.md).
