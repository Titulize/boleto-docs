---
sidebar_position: 8
title: 'Task 08: Base multi-tenant e auditoria'
---

# Task 08: Base multi-tenant e auditoria

- **Situação:** Em andamento (código e CI integrados; falta a demonstração em ambiente separado)
- **Início:** 2026-11-21
- **Última atualização:** 2026-11-22
- **Repositórios:** `boleto-docs`, `boleto-migrations`, `boleto-backend`

## Objetivo

O backend passa a ter as entidades `EmpresaGestora` e `Usuario`, o isolamento por tenant em duas camadas (`@TenantId` do Hibernate e RLS), a auditoria com Envers e revisão customizada, erros em Problem Details e logs JSON com `traceId`, tudo testado contra o schema real do `boleto-migrations`.

## Entregue

`boleto-migrations`, migração V2 (PR [#4](https://github.com/Titulize/boleto-migrations/pull/4), squash `ba80d4f`):

- `sql/V2__auditoria_empresa_gestora_tenant.sql`: gatilho `BEFORE INSERT` em `empresa_gestora_aud` que faz `tenant_id := id` ([ADR 0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md)). Só acréscimo (expand).
- `tests/sql/08d_aud_empresa_tenant.sql` com três casos (origem da plataforma preenche o tenant, valor informado é sobrescrito, outro tenant é recusado pela RLS com SQLSTATE 42501). `tests/08c_cnpj_configuravel.sh` passou a comparar com a quantidade de arquivos `V*.sql`. README atualizado.

`boleto-migrations`, composite action (PR [#5](https://github.com/Titulize/boleto-migrations/pull/5), squash `15444e6`):

- `.github/actions/imagem-migracoes/action.yml`: constrói a imagem de migração a partir de `$GITHUB_ACTION_PATH` e devolve o output `imagem`. A CI do próprio repositório usa a action. README atualizado.
- Configuração aplicada fora do código: `Actions > Access` do `boleto-migrations` em nível de organização (`PUT repos/Titulize/boleto-migrations/actions/permissions/access`, conferido com o `GET`: `access_level: organization`) ([ADR 0036](../adr/0036-schema-real-nos-testes-do-backend.md)).

`boleto-backend` (PR [#4](https://github.com/Titulize/boleto-backend/pull/4), squash `77b6967`, 34 arquivos):

- `empresas.EmpresaGestora` e `usuarios.Usuario` (com `UsuarioRepository`, `UsuarioServico`, `SituacaoUsuario`), ambas `@Audited`.
- `shared.tenant`: `ContextoTenant` em `ScopedValue`, `TenantIdResolver` estrito, `TenantJpaDialect` (`set_config(..., true)` por transação) e `TenantConfig` ([ADR 0037](../adr/0037-contexto-de-tenant-por-transacao.md)).
- `auditoria`: `RevisaoAuditoria`, `RevisaoAuditoriaListener`, `ConsultaAuditoria` e o diff por reflexão ([ADR 0038](../adr/0038-auditoria-com-envers.md)).
- `shared.erro` (Problem Details, [ADR 0040](../adr/0040-problem-details-e-catalogo-de-erros.md)) e `shared.log.TraceIdFilter` com logs JSON ([ADR 0041](../adr/0041-logs-json-com-traceid.md)).
- Dependências `hibernate-envers` e `spring-boot-starter-validation`, sem versão (BOM do Spring Boot 4.1.3).
- Testes com o schema real: `TestcontainersConfiguration`, `SchemaRealTest`, `IsolamentoPorTenantTest`, `AuditoriaUsuarioTest`, `ProblemDetailsTest` e `LogsJsonTest`; regra `contextoTenantSoLigadoPeloAuth` no `ArquiteturaTest`.
- `ci.yml` com a action do `boleto-migrations` fixada por SHA (`15444e6`), `AL2023_IMAGE` no cache de imagens e `MIGRATIONS_IMAGE` nos testes. README atualizado.

`boleto-docs` (este PR): ADRs [0036](../adr/0036-schema-real-nos-testes-do-backend.md) a [0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md), ADR 0033 como "Substituído em parte pelo 0036", páginas de arquitetura (`multitenancy-e-auditoria`, `modulos-backend`, `modelo-de-dados`, `containers` e a nova [Erros da API](../arquitetura/erros-da-api.md)), guias (`migracoes`, `ambiente-do-dev`, `compose-dev`), notas nos registros dos Tasks 6 e 7, índice, README e `tasks.md`.

Sem mudança no `versions.toml`: as duas dependências novas vêm do BOM do Spring Boot, que já está fixado lá. Não há tag nova.

## Verificação

Backend, registrado nas mensagens dos commits do PR #4 (execução local no Windows com Docker 29.8.0 e `MIGRATIONS_CONTEXT` apontando para o `boleto-migrations` com a V2):

| O quê | Como | Resultado |
|---|---|---|
| Build e testes | `gradlew spotlessApply` e `spotlessCheck check` | 38 testes, 0 falhas; Jacoco 206 de 223 linhas (92,4%) no primeiro commit e 92,3% no segundo; mínimo 80% |
| Imagem do backend | `docker build -t boleto-backend:t08 .` | passou |
| Isolamento pega regressão | `set_config` tirado do `TenantJpaDialect` e restaurado | 4 casos do `IsolamentoPorTenantTest` falharam |
| Falha clara sem o schema | `MIGRATIONS_CONTEXT` sem `Dockerfile` | `construirImagemMigracoes` abortou com a mensagem que nomeia a pasta |
| Versões e commits | `node .platform/sync-versions.mjs check --remote` e `npx commitlint --from origin/main --to HEAD` | passaram |

`boleto-migrations`, registrado no commit e no relatório da migração:

| O quê | Como | Resultado |
|---|---|---|
| Lint | `docker build --target lint .` | passou |
| Isolamento | `docker compose -p boleto-migrations-test -f compose.test.yml run --build --rm tests`, depois `down -v` | passou, com o `08d` |
| Casos negativos | `bash tests/negativos.sh` | todos passaram |
| Shell, versões, commits | ShellCheck dos `.sh`, `sync-versions check --remote`, `commitlint` | passaram |
| Imagem da action | `docker build` local da mesma linha que a action usa | passou |

### Workflows

| Repositório | Workflow | Evento | Run | Resultado |
|---|---|---|---|---|
| `boleto-migrations` | CI (`Conventional Commits` e `Lint, imagem e testes de isolamento (PostgreSQL real)`) | PR #4 | [44963756044](https://github.com/Titulize/boleto-migrations/actions/runs/44963756044) | verde |
| `boleto-migrations` | CI | `main` depois do squash `ba80d4f` | [44963963191](https://github.com/Titulize/boleto-migrations/actions/runs/44963963191) | verde |
| `boleto-migrations` | CI (`Conventional Commits` e o job do banco) | PR #5 | [44966944609](https://github.com/Titulize/boleto-migrations/actions/runs/44966944609) | verde |
| `boleto-migrations` | CI (o job de commits só roda em PR e foi pulado) | `main` depois do squash `15444e6` | [44967168472](https://github.com/Titulize/boleto-migrations/actions/runs/44967168472) | verde |
| `boleto-backend` | CI | PR #4, commit `d03bd4b` | [44966545393](https://github.com/Titulize/boleto-backend/actions/runs/44966545393) | **falhou** (sem `../boleto-migrations` no runner) |
| `boleto-backend` | CI | PR #4, commit `c21f9d8` | [44967444709](https://github.com/Titulize/boleto-backend/actions/runs/44967444709) | cancelado pelo `push --force-with-lease` |
| `boleto-backend` | CI (`Conventional Commits` e `Build, testes, Spotless, Jacoco e imagem`) | PR #4, commit `3e79b40` | [44967471979](https://github.com/Titulize/boleto-backend/actions/runs/44967471979) | verde |
| `boleto-backend` | CI (o job de commits só roda em PR e foi pulado) | `main` depois do squash `77b6967` | [44967834278](https://github.com/Titulize/boleto-backend/actions/runs/44967834278) | verde |

No run `44967471979`, a action do `boleto-migrations` foi resolvida no runner sem token e a imagem foi usada pelos testes. Os workflows do PR do `boleto-docs` (este) e da `main` depois dele constam no relatório final da tarefa: citá-los aqui exigiria outro PR.

### O que não foi verificado

- **A demonstração do plano (item 11).** Não foi executada: não existe `.agents/tasks/task-08/demo.md`. Faltam a tabela do diff salva a partir do `AuditoriaUsuarioTest -i` e a subida do Compose em outro projeto (`boleto-t08`) com a V2 aplicada pelo `flyway`, `/actuator/health` com `db` `UP` (prova do `validate` contra o schema real fora do Testcontainers) e uma linha de log JSON lida no `docker compose logs`.
- **A suíte do backend e as verificações do `boleto-migrations` na máquina de quem escreveu este registro.** Os números de testes e de cobertura vêm das mensagens dos commits. A CI do PR #4 do backend e as dos PRs do `boleto-migrations` repetiram os testes e passaram. O revisor do código também não reexecutou as suítes.
- **O comando `docker compose logs --no-log-prefix backend | jq -R 'fromjson? // .'`** do guia do Compose não foi executado contra uma imagem com logs JSON. O `boleto-dev` do desenvolvedor roda uma imagem anterior ao Task 8 (texto) e não foi tocado.
- A V2 não foi aplicada no `boleto-dev` (chega no próximo `up -d --build`).
- `gh secret list` foi bloqueado pelo ambiente. A action roda sem token e nenhum segredo foi criado, mas não se sabe se já existia algum no repositório.
- `REQUIRES_NEW` com outro contexto, transação `readOnly`, exclusão (`DEL`) e concorrência com `@Version` não têm teste.
- O cabeçalho `X-Tenant-Id` só foi testado numa rota de teste, não em controller real (não há controller ainda).

## Falhas e correções

- **Lint recusou a primeira V2** (`require-lock-timeout` e `require-statement-timeout` do Squawk). A V2 passou a definir os dois e a restaurá-los.
- **O primeiro `08d` falhou:** o caso de recusa estava errado, porque a RLS por tenant deixa a empresa gravar a própria auditoria. O caso "sem origem da plataforma" passou a usar outro tenant.
- **O teste de isolamento falhou uma vez** porque sobrou um PostgreSQL de uma execução anterior. `down -v` do projeto de teste e nova execução resolveram.
- **`tests/08c_cnpj_configuravel.sh` fixava `= "1"` migração** e falhou com a V2. Passou a comparar com a quantidade de `V*.sql`.
- **`TransactionManagerCustomizer` era desfeito** pelo `JpaTransactionManager`, que copia o dialeto da fábrica de entidades. Trocado por um `BeanPostProcessor`.
- **`handleExceptionInternal` recebia corpo nulo** nos erros herdados (405 e 415). `codigo` e `traceId` passaram a ser aplicados na resposta do `super`.
- **Revisão da primeira passada do backend** (commit `d03bd4b`): o log do Hibernate trazia `Key (email)=(...)` na violação de unicidade, e um `LOG.debug` registrava a exceção completa. O `SqlExceptionHelper` ficou em `OFF`, o `debug` saiu, o `ProblemDetailsTest` ganhou o caso do conflito de e-mail com `CapturedOutput`, e o teste do tenant diferente do contexto passou a exigir `DataAccessException`. O custo está no [ADR 0041](../adr/0041-logs-json-com-traceid.md).
- **Run `44966545393` do backend falhou:** a task `construirImagemMigracoes` não achou `../boleto-migrations` no runner. A correção foi a composite action do PR #5 do `boleto-migrations` e o `ci.yml` com o SHA dela (commit `3e79b40`).
- **`commitlint` reprovou o commit `fix(ci)`** por uma linha do corpo com mais de 100 colunas. O push foi feito antes de ler o resultado local. O commit foi corrigido com `git commit --amend` e `git push --force-with-lease`, só na branch do PR, e isso cancelou o run `44967444709`.
- **Limpeza:** `git worktree remove` do backend falhou com "Permission denied". O git já não lista o worktree e a branch local foi apagada, mas a pasta vazia `boleto-backend/.worktrees/task-08` continua, presa por outro processo. Não afeta nenhum arquivo.
- **Branches remotas que sobraram no `boleto-migrations`:** `feat/acao-imagem-migracoes` (do PR #5, já integrado). Junto dela seguem `docs/compose-up-completo` e `docs/task-06-fechamento`, de tarefas anteriores.

## Decisões e desvios do plano

- ADRs [0036](../adr/0036-schema-real-nos-testes-do-backend.md) a [0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md), como no plano. O ADR 0036 também registra a configuração de acesso por organização e o custo aceito.
- Dependências fora do `versions.toml`: a versão vem do BOM do Spring Boot, que já está lá. Decisão do passo de versões, que não alterou nada.
- A V2 e a action ficaram em dois PRs do `boleto-migrations` (#4 e #5), e não em um. A `main` do `boleto-migrations` ganhou a V2 antes da action.
- A auditoria de `tela` foi decidida e adiada para a tarefa do "Cadastro de Telas" ([ADR 0039](../adr/0039-auditoria-do-catalogo-tela.md)).
- As branches do backend e do `boleto-migrations` foram `feat/task-08-multitenant-auditoria`, `feat/task-08-migracao` e `feat/acao-imagem-migracoes`, e a do `boleto-docs`, `docs/task-08-multitenant-auditoria`, no lugar dos nomes do plano.

## Pendências

- **Demonstração em ambiente separado** (item 11 do plano): salvar a tabela do diff do `AuditoriaUsuarioTest` e subir o Compose num projeto separado. A tarefa só será marcada como concluída depois dela.
- **Task 9:** ligar o `ContextoTenant` ao JWT validado (único chamador autorizado), propagar o contexto onde houver `@Async` ou threads virtuais, repetir o teste do `X-Tenant-Id` em controller real, auditar `perfil*` e `usuario_perfil`.
- **Tarefa do "Cadastro de Telas":** migração com `tela_aud` e gatilho, entidade `Tela` e testes ([ADR 0039](../adr/0039-auditoria-do-catalogo-tela.md)).
- **Task 10:** CPF (dado pessoal) e sua proteção.
- **Testes que faltam:** `REQUIRES_NEW` com outro contexto, transação `readOnly`, `DEL` e concorrência com `@Version`.
- **Diagnóstico de erros em produção:** avaliar registrar o `SQLState` no log de erro interno ([ADR 0041](../adr/0041-logs-json-com-traceid.md)).
- **Limpeza manual:** a pasta `boleto-backend/.worktrees/task-08` e as três branches remotas do `boleto-migrations` citadas acima.
- **Manutenção:** todo bump da action do `boleto-migrations` exige trocar o SHA no `ci.yml` do `boleto-backend`.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-21 | V2 e teste no `boleto-migrations` (PR #4) |
| 2026-11-22 | Composite action no `boleto-migrations` (PR #5) e base multi-tenant no `boleto-backend` (PR #4) integradas |
| 2026-11-22 | ADRs 0036 a 0042, arquitetura, guias e este registro; Task 8 segue em andamento até a demonstração |
