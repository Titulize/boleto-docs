---
sidebar_position: 7
title: 'Task 07: Esqueleto do backend'
---
# Task 07: Esqueleto do backend
- **Situação:** Em andamento (backend e `boleto-docs` integrados com a CI verde; falta só corrigir o README do `boleto-backend`)
- **Início:** 2026-11-21
- **Última atualização:** 2026-11-21
- **Repositórios:** `boleto-docs`, `boleto-backend`
## Objetivo
Um backend Spring Boot que sobe em contêiner, conecta no PostgreSQL já migrado e responde `/actuator/health` e o Swagger, com os módulos da Fase 1 e as ferramentas de qualidade configurados, sem regra de negócio.
## Entregue
Passo A0, no `boleto-docs` (PR [#10](https://github.com/Titulize/boleto-docs/pull/10), squash `4663d2d`, tag **`v0.5.0`**):
- `versions.toml`: `google_java_format` em `[backend.tools]`.
- `scripts/sync-versions.mjs`: o alvo `backend` passou a gerar `.node-version` e instalar `node` no `mise.toml`, porque o commitlint do backend precisa de Node exato (princípio 3 do padrão). Testes e `versoes.md` ajustados.
- O `boleto-backend` foi inicializado com `init --tag v0.5.0`.
Parte A, no `boleto-backend` (PR [#1](https://github.com/Titulize/boleto-backend/pull/1), squash `b3e8eb5`; commit inicial `d7833fe` direto na `main` por exceção, [ADR 0031](../adr/0031-primeira-main-boleto-backend.md)):
- Build Gradle Kotlin DSL (Gradle Wrapper 9.9.2, Java 25, Spring Boot 4.1.3), Actuator, springdoc 3.2.0, Spring Modulith 2.1.3, ArchUnit 1.5.1, Spotless com google-java-format, Jacoco com mínimo de 80% de linhas, Testcontainers.
- Pacote `br.com.titulize.boleto` com os módulos `auth`, `usuarios`, `empresas`, `auditoria` e `shared` ([Módulos do backend](../arquitetura/modulos-backend.md)).
- Conexão com o PostgreSQL como `boleto_app`, `ddl-auto=validate`, sem Valkey e sem Flyway; Swagger desligado por padrão ([ADR 0032](../adr/0032-esqueleto-do-backend.md)).
- `Dockerfile` multi-stage em Amazon Linux 2023 (Corretto), usuário `10001`, JAR em camadas, `HEALTHCHECK`.
- CI (commitlint, `sync-versions check --remote`, validação do wrapper, Spotless, testes, Jacoco, build da imagem) e README ([ADR 0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md)).
Parte B, no `boleto-docs` (branch `feat/task-07-backend-compose-docs`):
- `docker-compose.yml`: serviço `backend` no profile `backend` (build de `BACKEND_CONTEXT`, `depends_on` no `postgres` saudável e no `flyway` concluído, porta `127.0.0.1:${BACKEND_PORT:-8080}`, healthcheck por `curl`). O `flyway` entra também no profile `backend` e usa `MIGRATIONS_CONTEXT`. Sem profile, `up -d --wait` continua subindo só PostgreSQL, Valkey e Mailpit ([ADR 0034](../adr/0034-servico-backend-no-compose.md)).
- `.env.example` (`BACKEND_PORT`, `BACKEND_CONTEXT`, `MIGRATIONS_CONTEXT`) e `scripts/compose.test.mjs` (teste do `backend` e do `flyway`).
- ADRs [0031](../adr/0031-primeira-main-boleto-backend.md) a [0034](../adr/0034-servico-backend-no-compose.md); ajuste de consequências no [ADR 0002](../adr/0002-backend-spring-java-gradle.md); [padrão do projeto](../guias/padrao-do-projeto.md) com o link do ADR 0031.
- Guias [Compose de desenvolvimento](../guias/compose-dev.md) (seção do backend, worktree e outro nome de projeto) e [Ambiente do desenvolvedor](../guias/ambiente-do-dev.md); arquitetura em [Módulos do backend](../arquitetura/modulos-backend.md) e [Containers](../arquitetura/containers.md); README.
## Compatibilidade com o Spring Boot 4.1 (ADR 0002)
Confirmada. Spring Boot 4.1.3, Spring Modulith 2.1.3 e springdoc 3.2.0 funcionam juntos, sem mudar versão. Provas: o contexto sobe (`BoletoApplicationTests`), o `ModulosTest` (`ApplicationModules.verify()`) passa, e o `DocumentacaoApiTest` obtém 200 em `/v3/api-docs` e `/swagger-ui/index.html` quando ligados e 404 quando desligados. Detalhes no [ADR 0032](../adr/0032-esqueleto-do-backend.md).
## Verificação
| O quê | Como | Resultado |
|---|---|---|
| Demonstração pelo Compose | `docker compose -p boleto-demo --profile backend up -d --build --wait` (ver abaixo) | passou: health `UP` com `db` `UP`, `/swagger-ui/index.html` 200, `/v3/api-docs` 200 |
| Usuário do processo e da conexão | `exec backend id -u` e `pg_stat_activity` | `10001` e `boleto_app` |
| Sem profile só a infraestrutura | `docker compose config --services` | `mailpit`, `postgres`, `valkey` |
| Com profile `backend` | `docker compose --profile backend config --services` | `postgres`, `flyway`, `backend`, `mailpit`, `valkey` |
| Testes do `boleto-docs` | `npm test` | 43 passam, 0 falham |
| Versões do `boleto-docs` | `npm run validate`, `npm run sync:check` | válido, "versões em dia" |
| Backend, build e testes | `gradlew build` no commit (9 testes, Spotless, Jacoco 80%) e job `Build, testes, Spotless, Jacoco e imagem` da CI | passou |
| CI do A0 (`boleto-docs` PR #10 e `main`) | runs [44940118654](https://github.com/Titulize/boleto-docs/actions/runs/44940118654) (CI) e [44940118627](https://github.com/Titulize/boleto-docs/actions/runs/44940118627) (Documentação); na `main` 44940262338 (CI) e 44940262247 (Documentação) | todos verdes |
| CI do backend (PR #1 e `main`) | run [44940609705](https://github.com/Titulize/boleto-backend/actions/runs/44940609705) (jobs `Build, testes, Spotless, Jacoco e imagem` e `Conventional Commits`); `main`: 44941042130 | verdes |
| CI e build do site deste PR | commitlint, build do site e workflows `CI` e `Documentação` do PR do `boleto-docs` | ver "Pendências" |
### Demonstração
Projeto `boleto-demo`, com `-p` e outras portas (PostgreSQL 25434, backend 18080, Valkey 26380, Mailpit 21026 e 28026), sem parar o `boleto-dev`. O `up` foi construído a partir dos clones `boleto-backend` (`b3e8eb5`) e `boleto-migrations` (`a2328e7`). O `flyway` saiu com código 0 e o backend ficou saudável em cerca de 1 minuto. Respostas reais de `http://localhost:18080`:
```text
### GET /actuator/health
HTTP/1.1 200 
Content-Type: application/vnd.spring-boot.actuator.v3+json
Transfer-Encoding: chunked
Date: Sat, 21 Nov 2026 19:37:15 GMT

{"components":{"db":{"status":"UP"},"diskSpace":{"status":"UP"},"livenessState":{"status":"UP"},"ping":{"status":"UP"},"readinessState":{"status":"UP"},"ssl":{"status":"UP"}},"groups":["liveness","readiness"],"status":"UP"}
### GET /swagger-ui (segue redirecionamentos)
HTTP/1.1 404 
Content-Type: application/json
Transfer-Encoding: chunked
Date: Sat, 21 Nov 2026 19:37:15 GMT

### GET /swagger-ui/index.html (primeiras linhas)
<!-- HTML for static distribution bundle build -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="./swagger-ui.css" />
    <link rel="stylesheet" type="text/css" href="index.css" />
    <link rel="icon" type="image/png" href="./favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="./favicon-16x16.png" sizes="16x16" />
  </head>

### GET /v3/api-docs
HTTP/1.1 200 
Content-Type: application/json
Content-Length: 181
Date: Sat, 21 Nov 2026 19:37:15 GMT

{"openapi":"3.1.0","info":{"title":"OpenAPI definition","version":"v0"},"servers":[{"url":"http://localhost:18080","description":"Generated server url"}],"paths":{},"components":{}}
### uid do processo
10001
### usuários conectados ao banco
boleto_app
### serviços sem profile
mailpit
postgres
valkey
### flyway
exit=0
```
`/swagger-ui` sem extensão responde 404. O endereço da interface é `/swagger-ui.html` (302 para `/swagger-ui/index.html`) ou `/swagger-ui/index.html` (200).
Depois da demonstração, `docker compose -p boleto-demo --profile backend down -v --remove-orphans` removeu só o ambiente `boleto-demo`. Os contêineres e volumes do `boleto-dev` continuaram (`localhost:15433` aceita conexão). O texto completo está em `.agents/tasks/task-07/demo.md`.
Não verificado:
- Caso de senha errada: o `flyway` regrava a senha da `boleto_app` com o mesmo `BOLETO_APP_PASSWORD`, então trocar só a variável não isola a falha do backend.
- Linux nativo na máquina local: o `./gradlew` rodou só no Docker e na CI (Ubuntu); o `gradlew.bat` rodou no Windows.
- Publicação da imagem num registro e smoke com migração e backend na CI (Task 14).
- O código de saída do `up` da demonstração não foi capturado (o shell da ferramenta devolveu o controle antes do fim). O log mostra todos os serviços saudáveis e o `flyway` terminado, sem erro.
## Falhas e correções
- `/swagger-ui` responde 404: o plano e o README do `boleto-backend` citavam esse caminho. Os guias do `boleto-docs` passaram a usar `/swagger-ui.html`. O README do backend ainda cita `/swagger-ui` (ver Pendências).
- O smoke do `bootRun` no backend não chegou a `UP` por divergência entre a senha local do `boleto-dev` e o padrão do profile `dev` (registro do coder do backend). A demonstração pelo Compose, com a senha gravada pelo `flyway`, passou.
- Na demonstração, duas tentativas iniciais de `up` ficaram pela metade e deixaram contêineres `Created` do próprio `boleto-demo`, o que causou `container name ... is already in use` na tentativa seguinte. Rodar o `up` de novo resolveu. Foi um efeito da execução pela ferramenta, não do Compose.
- Nenhuma falha de CI nos workflows do A0 nem do backend.
## Decisões e desvios do plano
- [ADR 0031](../adr/0031-primeira-main-boleto-backend.md): exceção do commit inicial `d7833fe` direto na `main` do `boleto-backend`, autorizada pelo usuário. Novo ADR em vez de estender o 0023, que é aceito e trata só do `boleto-migrations`.
- [ADR 0032](../adr/0032-esqueleto-do-backend.md), [0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md) e [0034](../adr/0034-servico-backend-no-compose.md): decisões do plano.
- A demonstração usou `-p boleto-demo` em vez do `boleto-t07` do plano.
## Pendências
- Ajustar o README do `boleto-backend` (`/swagger-ui` para `/swagger-ui.html`) em outro PR do backend. A tarefa muda para "Concluída" depois disso.
- Para outros tasks: Valkey, Lettuce e Bucket4j no Task 9; schema nos testes do backend no Task 8; smoke de migração mais backend na CI e verificação de dependências do Gradle no Task 14.
## Histórico
| Data | Atualização |
|---|---|
| 2026-11-21 | A0 (tag `v0.5.0`) e esqueleto do `boleto-backend` integrados |
| 2026-11-21 | Serviço `backend` no Compose, demonstração, ADRs 0031 a 0034 e documentação || 2026-11-21 | PR #11 do `boleto-docs` integrado; pendência restante: README do `boleto-backend` |
