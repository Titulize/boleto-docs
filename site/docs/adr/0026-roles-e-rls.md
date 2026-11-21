---
title: 'ADR 0026: Roles do banco e RLS forçado'
---

# ADR 0026: Roles do banco e RLS forçado

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O [ADR 0008](./0008-multitenancy.md) define o isolamento por `tenant_id` com Row-Level Security. O backend usa uma role sem DDL e sem `BYPASSRLS`, e todo o schema pertence ao `boleto-migrations`. O PostgreSQL não aplica RLS ao dono da tabela, a menos que a tabela use `FORCE ROW LEVEL SECURITY`, e com `FORCE` o dono também passa pela política. Uma função do dono, por isso, não enxergaria nada. As funções que resolvem o tenant antes do login precisam ler linhas de qualquer tenant, mas só as colunas necessárias.

## Decisão

- **`boleto_owner`:** `NOLOGIN`, dono do schema e de todos os objetos. Toda tabela com RLS usa `ENABLE` e `FORCE ROW LEVEL SECURITY`.
- **`boleto_app`:** `LOGIN`, só DML nos objetos que precisa (`SELECT`, `INSERT`, `UPDATE` e, em poucas tabelas, `DELETE`), `NOBYPASSRLS`, sem `SUPERUSER`, `CREATEROLE` e `CREATEDB`. É a role do backend. Tem `search_path = boleto`. Não lê `flyway_schema_history` nem cria objetos em `boleto` ou `public`.
- **`boleto_funcoes`:** `NOLOGIN`, dona das funções `SECURITY DEFINER`, com `GRANT SELECT` só nas colunas que as funções usam e uma política `FOR SELECT USING (true)` limitada a `empresa_gestora`, `usuario` e `token_usuario`. As funções têm `search_path` fixo, `REVOKE ... FROM PUBLIC` e `EXECUTE` só para `boleto_app`.
- **Política por tenant:** tabelas com `tenant_id` têm uma política `FOR ALL` com `USING` e `WITH CHECK` iguais a `tenant_id = boleto.tenant_atual()`. A função devolve `nullif(current_setting('app.tenant_id', true), '')::uuid`. Sem a variável o resultado é nulo e nenhuma linha passa (falha fechada). A aplicação define a variável com `SET LOCAL` dentro da transação.
- **Senha da `boleto_app`:** não vai na migração. O callback `afterMigrate` aplica `ALTER ROLE boleto_app LOGIN PASSWORD` a cada execução, a partir de uma variável de ambiente. A senha muda sem nova migração e não fica no histórico do Flyway.
- **Execução:** o Flyway conecta com a conexão administrativa (`postgres` em dev e na CI, usuário de migração em produção). A `V1` cria as roles, passa o schema para `boleto_owner`, concede `boleto_owner` ao usuário atual e faz `SET ROLE boleto_owner` antes de criar as tabelas, terminando com `RESET ROLE`. As migrações seguintes começam com `SET ROLE boleto_owner;` e terminam com `RESET ROLE;`.
- **Teste de catálogo:** um teste na CI falha se algum objeto do schema `boleto` tiver outro dono (exceto as funções e `flyway_schema_history`) ou se uma tabela com `tenant_id` não tiver RLS ativo e forçado. Ele protege as migrações futuras.

## Consequências

- Esquecer o `SET ROLE` numa migração nova é pego pelo teste de catálogo.
- O dono das tabelas também passa pelo RLS. Uma migração que precise mexer em dados de um tenant define o tenant antes (como o `afterMigrate` faz para o CNPJ da Titulize).
- As funções de resolução enxergam todos os tenants, mas só nas colunas liberadas e com o retorno limitado a `tenant_id`.
- A senha de dev da `boleto_app` vive só no Compose (valor de desenvolvimento). Em produção vem do cofre de segredos da infraestrutura.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Aplicação como dono das tabelas, sem `FORCE` | O RLS não se aplicaria ao dono e um erro de configuração abriria tudo |
| Funções `SECURITY DEFINER` do `boleto_owner` | Com `FORCE` o dono não vê linhas, e sem `FORCE` ele leria tudo. A role própria limita o que as funções leem |
| `BYPASSRLS` para o caminho de login | Dá à aplicação o poder de ler qualquer tenant |
| Senha da `boleto_app` dentro da `V1` | Ficaria gravada no repositório e no histórico do Flyway, e trocar exigiria nova migração |
