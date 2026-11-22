---
sidebar_position: 5
title: Migrações do banco
---

# Migrações do banco

Todo o schema do banco pertence ao repositório `boleto-migrations`. Ninguém altera o banco por outro caminho. Este guia cobre o uso em desenvolvimento. O que está em cada arquivo e os testes ficam no README do `boleto-migrations`. As decisões estão nos [ADR 0023](../adr/0023-primeira-main-boleto-migrations.md) a [0030](../adr/0030-manutencao-de-dados-e-origem-do-tenant.md), [0036](../adr/0036-schema-real-nos-testes-do-backend.md) e [0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md).

## Aplicar no Compose de desenvolvimento

O `boleto-migrations` precisa estar ao lado do `boleto-docs` (`../boleto-migrations`). Na raiz do `boleto-docs`:

```bash
docker compose up -d                         # sobe tudo: o flyway migra a cada up e o backend espera por ele
docker compose run --build --rm flyway      # só a migração: sobe o PostgreSQL se preciso, aplica e sai
echo $?                                     # 0 se deu certo (no PowerShell: $LASTEXITCODE)
```

A imagem roda uma vez, valida os checksums e as pendências, aplica as pendentes, confere de novo (`validate`) e sai. O `up -d` padrão também roda o `flyway` (o backend só inicia depois dele). Para aplicar sem subir o backend, use o `run`. Qualquer erro dá código diferente de zero: migração alterada depois de aplicada, SQL inválido, banco inacessível, senha errada ou variável obrigatória ausente. Rodar de novo sem migração nova não faz nada.

Use `run --rm`, não `up --exit-code-from flyway`: o `up` implica `--abort-on-container-exit` e para o PostgreSQL ao fim.

## Ver o schema

```bash
docker compose exec postgres psql -U postgres -d boleto -c "\dn" -c "\dt boleto.*" -c "\du"
docker compose exec postgres psql -U postgres -d boleto -c "select version, description, success from boleto.flyway_schema_history order by installed_rank"
```

O backend usa a role `boleto_app` (senha `BOLETO_APP_PASSWORD`, padrão `boleto_app_dev`, aplicada a cada execução). Para ver o que ela enxerga, conecte com ela e defina o tenant na transação:

```bash
docker compose exec -e PGPASSWORD=boleto_app_dev postgres psql -h localhost -U boleto_app -d boleto
```

```sql
begin;
select set_config('app.tenant_id', '00000000-0000-7000-8000-000000000001', true);  -- Titulize
select id, nome from empresa_gestora;
rollback;
```

Sem o `set_config` as consultas devolvem 0 linhas.

## Reset do banco

`docker compose down -v` apaga os dados do `boleto-dev`. Depois, `docker compose up -d` recria o schema (o `flyway` roda no `up`). Para não tocar o ambiente em uso, use outro nome de projeto e outra porta: `POSTGRES_PORT=15432 docker compose -p boleto-t6 up -d --wait postgres` e depois `POSTGRES_PORT=15432 docker compose -p boleto-t6 run --build --rm flyway`, terminando com `docker compose -p boleto-t6 down -v`.

## Criar uma migração

No `boleto-migrations`, em branch e PR:

1. Arquivo novo em `sql/` com o nome `V<n>__descricao.sql` (`n` é o próximo número).
2. Comece com `SET ROLE boleto_owner;` e termine com `RESET ROLE;`. O teste de catálogo falha se um objeto ficar com outro dono.
3. Toda tabela de negócio leva `tenant_id`, RLS ativo e forçado e uma política por tenant (copie o padrão da V1).
4. Dê à `boleto_app` só o DML de que ela precisa.
5. Nunca edite uma migração já aplicada: o Flyway confere o checksum e falha. Para corrigir, crie outra.
6. Para uma tela nova, a migração faz `insert into boleto.tela (...)` junto com o código da tela.

### Regra de compatibilidade (expand/contract)

No deploy o backend antigo ainda roda sobre o schema novo. Cada migração precisa ser compatível com a versão anterior do backend.

| Numa migração só | Em duas migrações, com um deploy do backend entre elas |
|---|---|
| Criar tabela, coluna anulável ou com valor padrão, índice | Remover ou renomear coluna ou tabela |
| Acrescentar restrição que o backend antigo já cumpre | Tornar uma coluna `NOT NULL` sem valor padrão |

Exemplo para trocar `usuario.telefone` por `usuario.celular`:

1. Migração `V5`: `alter table boleto.usuario add column celular varchar(20);` (expand). Deploy do backend que grava nas duas colunas e lê da nova.
2. Backend deixa de usar `telefone`. Deploy.
3. Migração `V6`: `alter table boleto.usuario drop column telefone;` (contract).

O lint (Squawk) bloqueia `DROP COLUMN`, renomeação e `NOT NULL` sem padrão. Uma exceção é por arquivo e por regra, com o motivo escrito no próprio arquivo.

### Migração de dados em tabela de tenant

A dona das tabelas (`boleto_owner`) também passa pelo RLS forçado. Um `UPDATE` ou `INSERT ... SELECT` numa tabela de tenant, feito sem `app.tenant_id` definido, afeta 0 linhas e termina sem erro. Para cada tenant, dentro da transação, defina o tenant com `SET LOCAL app.tenant_id = '<uuid>'` (ou `select set_config('app.tenant_id', '<uuid>', true)`), rode a alteração e confira o número de linhas afetadas. O padrão completo (`SET ROLE boleto_owner`, `SET LOCAL`, conferência e `RESET ROLE`) está no README do `boleto-migrations`. Detalhes no [ADR 0030](../adr/0030-manutencao-de-dados-e-origem-do-tenant.md).

## Testes

No `boleto-migrations`, antes de enviar (precisa do Docker; os `.sh` rodam no Git Bash no Windows):

```bash
docker build --target lint .                                                        # Squawk
docker compose -p boleto-migrations-test -f compose.test.yml run --build --rm tests  # isolamento por tenant
docker compose -p boleto-migrations-test -f compose.test.yml down -v
bash tests/negativos.sh                                                              # contrato da imagem
```

O teste de isolamento roda como `boleto_app` contra um PostgreSQL 18 real e prova, entre outros pontos, que com o tenant A ativo a role da aplicação não lê nem grava dados do tenant B, mesmo sem filtro na consulta. Os casos negativos provam que a imagem sai com código diferente de zero e a mensagem esperada quando uma migração foi alterada, tem SQL inválido, a senha está errada, o banco está inacessível ou há migração pendente no `validate`. O caso de lint exige as regras `ban-drop-column`, `renaming-column` e `adding-not-nullable-field` do Squawk.

## Migrações aplicadas

| Versão | Arquivo | O que faz |
|---|---|---|
| V1 | `V1__schema_inicial.sql` | Schema inicial, roles, funções e RLS ([ADR 0025](../adr/0025-modelo-de-dados-v1.md)) |
| V2 | `V2__auditoria_empresa_gestora_tenant.sql` | Gatilho que preenche `tenant_id` em `empresa_gestora_aud` ([ADR 0042](../adr/0042-v2-tenant-da-auditoria-da-empresa.md)). Só acréscimo (expand) |

A V2 define `lock_timeout` e `statement_timeout` e os restaura no fim: o lint (Squawk) recusa uma migração sem eles. No `boleto-dev`, a V2 chega no próximo `docker compose up -d --build`, sem apagar dados.

## O backend e o schema

O `boleto-backend` não tem Flyway nem cópia do SQL ([ADR 0036](../adr/0036-schema-real-nos-testes-do-backend.md)). Ele usa o schema do `boleto-migrations` de dois jeitos:

- **Testes locais:** a tarefa Gradle `construirImagemMigracoes` roda `docker build -t boleto-migrations:teste ../boleto-migrations`, e o Testcontainers aplica a imagem num PostgreSQL novo. `MIGRATIONS_CONTEXT` troca a pasta (worktree) e `MIGRATIONS_IMAGE` indica uma imagem pronta. Se mudou o SQL, rode `.\gradlew.bat test` no backend com o `boleto-migrations` na branch da mudança.
- **CI do backend:** o `ci.yml` usa a composite action `Titulize/boleto-migrations/.github/actions/imagem-migracoes`, fixada por SHA do commit, que constrói a imagem e a entrega aos testes em `MIGRATIONS_IMAGE`. A action roda sem token porque o acesso de Actions do `boleto-migrations` está no nível da organização (`gh api repos/Titulize/boleto-migrations/actions/permissions/access` devolve `access_level: organization`).

**Regra:** uma migração nova só chega à CI do backend depois de integrada no `boleto-migrations` e de o `ci.yml` do `boleto-backend` receber o SHA do commit dela. Sem trocar o SHA, a CI do backend continua testando o schema antigo.

## Produção

A migração é o primeiro passo do deploy ([ADR 0027](../adr/0027-migracao-primeiro-passo.md)). A mesma imagem roda uma vez na VPC (ECS Fargate ou Lambda), com a conexão por variáveis de ambiente, e o deploy do backend e depois o do frontend só acontecem se ela sair com 0. O encadeamento no pipeline e a publicação da imagem são do Task 14. Requisitos já definidos:

- `FLYWAY_URL` com `sslmode=verify-full` (por exemplo `jdbc:postgresql://host:5432/db?sslmode=verify-full`), porque a senha da `boleto_app` trafega em `ALTER ROLE ... PASSWORD`.
- `FLYWAY_PLACEHOLDERS_APP_PASSWORD` e, se necessário, `FLYWAY_PLACEHOLDERS_TITULIZE_CNPJ` vindos do cofre de segredos. O CNPJ do seed é valor de teste.
- Um usuário de migração com permissão para criar roles e schema, diferente da `boleto_app`.
