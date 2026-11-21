---
title: 'ADR 0030: Manutenção de dados pela dona das tabelas e origem do tenant'
---

# ADR 0030: Manutenção de dados pela dona das tabelas e origem do tenant

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

A implementação da V1 no `boleto-migrations` (Task 6, parte B) mostrou três pontos que os [ADR 0025](./0025-modelo-de-dados-v1.md), [ADR 0026](./0026-roles-e-rls.md) e [ADR 0028](./0028-lint-sql-e-testes.md) não fixavam:

1. Com `FORCE ROW LEVEL SECURITY`, a `boleto_owner` também passa pelo RLS. Uma migração de dados feita como dona, numa tabela de tenant, afeta 0 linhas e termina com sucesso, sem erro.
2. O CNPJ da Titulize é trocado a cada execução pelo `afterMigrate.sql`, sem nova migração, e isso exige que a dona enxergue uma linha de `empresa_gestora`.
3. As políticas de `empresa_gestora` (`INSERT`), de `empresa_gestora_aud` e de `tela` dependem de `app.tenant_origem_id`, uma variável de sessão que a própria `boleto_app` consegue alterar.

## Decisão

- **Política mínima para a dona.** Só `empresa_gestora` tem uma política para a `boleto_owner` (`dona_manutencao`), limitada à linha do tenant ativo (`id = app.tenant_id`), para o `afterMigrate` trocar o CNPJ da Titulize. As tabelas de tenant (`usuario`, `perfil`, `token_usuario` e as demais) não têm política para a dona.
- **Migração de dados define o tenant.** Uma migração futura que precise de `UPDATE` ou `INSERT ... SELECT` numa tabela de tenant roda um tenant por vez: `select set_config('app.tenant_id', '<uuid>', false)` antes e a limpeza depois. Se precisar tocar todos os tenants, a própria migração declara uma política de manutenção explícita, que o `DROP POLICY` remove no fim. O guia [Migrações do banco](../guias/migracoes.md) e o README do `boleto-migrations` registram o aviso.
- **A origem do tenant é um contrato do backend.** O banco usa `app.tenant_origem_id` para decidir quem é a plataforma, mas não consegue provar que o valor veio de um token autenticado. O backend (Task 8) define as duas variáveis só a partir do JWT validado e nunca a partir de dados da requisição. O isolamento entre tenants comuns não depende disso: `app.tenant_id` sozinho já filtra tudo.
- **Exceções do lint por arquivo.** O lint não usa exclusão global no `.squawk.toml`. A V1 declara no próprio arquivo, com justificativa, as regras que ficam de fora (`-- squawk-ignore-file ...`), e as demais migrações seguem todas as regras. Isto ajusta a redação do [ADR 0028](./0028-lint-sql-e-testes.md).
- **Teste na CI com `run`.** O teste de isolamento roda com `docker compose run --build --rm tests`. O `up --abort-on-container-exit` não serve: o serviço `flyway` termina com sucesso e derruba o `tests` antes de ele rodar.
- **Conexão de produção com TLS.** A senha da `boleto_app` viaja em `ALTER ROLE ... PASSWORD` durante a migração. Em produção a `FLYWAY_URL` deve usar `sslmode=verify-full`, e quem opera o banco precisa saber que `log_statement=ddl` pode registrar o comando.

## Consequências

- Um backfill esquecido de definir o tenant não corrompe nada, mas também não faz nada. A revisão da migração confere o número de linhas afetadas.
- A auditoria do Envers deve gravar `tenant_origem_id` sempre a partir do mesmo ponto do código do backend (Task 8).
- Os testes de escrita (`05_isolamento_escrita`) falham quando uma política permissiva é injetada em `usuario`. Isso foi verificado à mão (ver [Task 6](../progresso/task-06-boleto-migrations.md)).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| `BYPASSRLS` para a dona | Qualquer erro numa migração leria e gravaria em todos os tenants, e o teste de catálogo deixaria de provar o RLS forçado |
| Política da dona em todas as tabelas de tenant | Abre uma segunda porta em cada tabela só para um caso raro (backfill) |
| Trocar o CNPJ da Titulize por nova migração | Exige uma migração a cada troca de valor e grava o CNPJ real no histórico do Flyway |
| Gravar a origem do tenant numa tabela de sessão | Acrescenta estado no banco sem resolver quem escreve nele: continua sendo o backend |
