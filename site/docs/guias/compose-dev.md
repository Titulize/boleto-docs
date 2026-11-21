---
sidebar_position: 4
title: Compose de desenvolvimento
---

# Compose de desenvolvimento

A infraestrutura local (PostgreSQL, Valkey e Mailpit) roda no Docker Compose, em `compose/` do `boleto-docs`. O requisito é o mesmo do [ambiente do desenvolvedor](./ambiente-do-dev.md): Docker com Compose. Nenhum comando exige administrador. As decisões estão no [ADR 0020](../adr/0020-compose-dev.md).

## Serviços

| Serviço | Imagem (`versions.toml`) | No host | Para que serve |
|---|---|---|---|
| `postgres` | PostgreSQL 18.7 | `127.0.0.1:5432` | Banco `boleto` |
| `valkey` | Valkey 9.1.4 ([ADR 0006](../adr/0006-valkey.md)) | `127.0.0.1:6379` | Compatível com Redis, com senha |
| `mailpit` | Mailpit 1.34.0 | SMTP `127.0.0.1:1025`, interface `http://localhost:8025` | Captura todo e-mail enviado |

As portas ficam só em `127.0.0.1`: outras máquinas da rede não alcançam os serviços.

O banco sobe só com o superusuário e o banco `boleto`. O schema e as roles de migração e de aplicação são do `boleto-migrations` (Task 6).

## Comandos

Na raiz do `boleto-docs` (os scripts também funcionam chamados de outra pasta, pelo caminho completo):

```powershell
# Windows (PowerShell 7 ou Windows PowerShell 5.1)
.\compose\dev.ps1 up            # sobe e espera todos ficarem saudáveis
.\compose\dev.ps1 down          # para os containers (os dados continuam)
.\compose\dev.ps1 reset         # apaga os dados e sobe de novo (pede confirmação)
.\compose\dev.ps1 reset -Yes    # sem confirmação
.\compose\dev.ps1 ps            # estado dos serviços
.\compose\dev.ps1 logs postgres # últimas 100 linhas de log de um serviço
```

```bash
# Linux e macOS
compose/dev.sh up
compose/dev.sh down
compose/dev.sh reset
compose/dev.sh reset --yes
compose/dev.sh ps
compose/dev.sh logs postgres
```

Códigos de saída: `0` sucesso, `1` falha (Docker parado, serviço que não ficou saudável em 120 s, porta ocupada) e `2` uso incorreto.

- `up` cria o `compose/.env` a partir do `compose/.env.example` na primeira vez e espera os healthchecks (`docker compose up --wait`). Se algo falhar, mostra o estado e os últimos logs.
- `down` remove os containers e mantém os volumes.
- `reset` remove os containers e os volumes `boleto-dev_postgres_data` e `boleto-dev_valkey_data` e sobe tudo de novo. Não apaga imagens, o `compose/.env` nem o volume do site de documentação. Fora de um terminal interativo, só roda com `-Yes` / `--yes` (sem isso, sai com código 2).

## Conectando

Valores do `compose/.env.example`. São só para desenvolvimento local.

| Serviço | Endereço | Credenciais |
|---|---|---|
| PostgreSQL | `jdbc:postgresql://localhost:5432/boleto` | `postgres` / `postgres_dev` (até o Task 6 criar as roles) |
| Valkey | `redis://localhost:6379` | senha `valkey_dev` (sem usuário) |
| Mailpit SMTP | `localhost:1025` | sem autenticação |
| Mailpit interface | `http://localhost:8025` | |

Para abrir o `psql` dentro do container:

```bash
docker compose -p boleto-dev exec postgres psql -U postgres -d boleto
```

## Mudando portas e senhas

Edite o `compose/.env` (não vai para o git) e rode `up` de novo. Variáveis: `POSTGRES_PORT`, `VALKEY_PORT`, `MAILPIT_SMTP_PORT`, `MAILPIT_UI_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` e `VALKEY_PASSWORD`. Uma variável de ambiente do shell com o mesmo nome vence o `.env`.

Usuário e senha do PostgreSQL só valem na criação do volume. Depois de mudá-los, rode `reset`.

## De onde vêm as imagens

O `compose/docker-compose.yml` não tem tag nem digest. Ele usa `${POSTGRES_IMAGE}`, `${VALKEY_IMAGE}` e `${MAILPIT_IMAGE}`, definidas no `.platform/versions.env`, que a [sincronização](./versoes.md) gera a partir do `versions.toml`. Para trocar uma versão, altere o `versions.toml`.

Os atalhos passam dois arquivos de variáveis ao Compose. Para chamar o `docker compose` direto, na raiz do `boleto-docs`, repita os dois:

```bash
docker compose -f compose/docker-compose.yml --env-file .platform/versions.env --env-file compose/.env ps
```

## Problemas conhecidos

- **Porta ocupada** (por exemplo, um PostgreSQL instalado na máquina): o `up` mostra `porta ocupada no host` e o caminho do `.env`. Mude a porta lá.
- **Limite de pulls do Docker Hub:** as imagens do Valkey e do Mailpit vêm do `docker.io`, que limita pulls anônimos. Se o pull falhar, espere e tente de novo, ou faça `docker login`.
- **Volume do PostgreSQL 18:** o volume é montado em `/var/lib/postgresql`, não em `/var/lib/postgresql/data`. No PostgreSQL 18 os dados ficam em `/var/lib/postgresql/18/docker`.
- **Windows PowerShell 5.1:** os scripts são UTF-8 com BOM e CRLF (o `.gitattributes` garante o CRLF). Se o editor salvar sem BOM, os acentos das mensagens saem trocados.

## Observabilidade

O profile `observability` com o Grafana LGTM (`OTEL_LGTM_IMAGE`, já no `versions.env`) entra no Task 11, quando o backend passar a emitir telemetria ([ADR 0014](../adr/0014-observabilidade.md)). Hoje o compose não tem esse serviço.

## Como é testado

| Teste | O que cobre | Onde roda |
|---|---|---|
| `compose/tests/verify.sh` e `verify.ps1` | Espera todos os serviços ficarem `healthy` (falha se algum não tiver healthcheck), `select 1` no PostgreSQL, `PONG` no Valkey com senha e `NOAUTH` sem senha, HTTP 200 em `/` e `/api/v1/info` do Mailpit e conexão TCP em `127.0.0.1` em todas as portas | Local e CI (Linux) |
| `compose/tests/dev.tests.ps1` | Lógica do `dev.ps1` sem Docker: leitura do `.env`, precedência das variáveis, resposta da confirmação do `reset`, argumentos do Compose | CI no PowerShell 7 e no 5.1 |
| `scripts/compose.test.mjs` (`npm test`) | Toda imagem vem de uma variável `*_IMAGE` do `versions.env` com digest, todo serviço tem healthcheck, toda porta fica em `127.0.0.1`, toda variável obrigatória está definida | Local e CI |

Os verificadores não sobem nem derrubam nada. Para rodar:

```powershell
.\compose\dev.ps1 up
.\compose\tests\verify.ps1
```

```bash
compose/dev.sh up
compose/tests/verify.sh
```

Na CI, o job `Compose de desenvolvimento (Linux)` roda o ciclo inteiro (`up`, verificação, `reset` com e sem `--yes`, `down`) com o `dev.sh` e depois com o `dev.ps1` no PowerShell 7. O runner Windows não roda containers Linux, por isso o job `Compose (Windows PowerShell 5.1)` cobre a sintaxe e a lógica.
