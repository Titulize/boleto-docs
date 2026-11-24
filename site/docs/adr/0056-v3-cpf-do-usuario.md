---
title: 'ADR 0056: V3, CPF do usuário'
---

# ADR 0056: V3, CPF do usuário

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

O [ADR 0025](./0025-modelo-de-dados-v1.md) e o [ADR 0015](./0015-lgpd.md) deixaram o CPF para uma migração posterior, que a documentação chamava de V2. A V2 acabou sendo o gatilho de `empresa_gestora_aud` ([ADR 0042](./0042-v2-tenant-da-auditoria-da-empresa.md)), então o CPF entra na V3. O desenho de cifra e índice está no [ADR 0054](./0054-cpf-criptografado-e-blind-index.md).

## Decisão

A migração `V3__cpf_do_usuario.sql` do `boleto-migrations` acrescenta, em `boleto.usuario`:

| Objeto | Definição |
|---|---|
| `cpf_cifrado` | `bytea`, anulável |
| `cpf_indice` | `bytea`, anulável |
| `cpf_chave_versao` | `bigint`, anulável |
| `usuario_cpf_ck` | Os três são nulos ou nenhum é. Se preenchidos: `cpf_cifrado` com 29 a 64 bytes, `cpf_indice` com 32 bytes e `cpf_chave_versao` maior que 0 |
| `usuario_tenant_cpf_indice_uk` | Índice único parcial em `(tenant_id, cpf_indice)` onde `cpf_indice is not null`. Vários usuários sem CPF convivem |

- **Só expand.** Colunas anuláveis, check que aceita as três nulas e índice parcial. O backend do Task 9 não informa essas colunas e continua compatível ([regra expand/contract](../guias/migracoes.md#regra-de-compatibilidade-expandcontract)).
- **Sem novos grants, sem mudança de RLS.** A `boleto_app` já tem `select, insert, update` na tabela. A política por tenant cobre as colunas novas.
- **CPF fora do `usuario_aud`.** A tabela de auditoria não ganha coluna de CPF, e um teste de banco confere isso no `information_schema`.
- **Cabeçalho da V2.** `SET ROLE boleto_owner`, `lock_timeout` e `statement_timeout` definidos e restaurados, `RESET ROLE` no fim.
- **Lint (Squawk).** O arquivo usa `squawk-ignore-file` para duas regras, com o motivo escrito nele:
  - `require-concurrent-index-creation`: o Flyway roda a migração numa transação e `CREATE INDEX CONCURRENTLY` não roda dentro dela. A tabela `usuario` não tem tráfego de produção.
  - `constraint-missing-not-valid`: na mesma transação, `NOT VALID` seguido de `VALIDATE` não reduz o bloqueio, e a tabela é pequena com colunas novas nulas.
- **Teste de banco** `tests/sql/08e_cpf_usuario.sql`, como `boleto_app`: os três campos preenchidos entram; só `cpf_cifrado` sem `cpf_indice` falha (`23514`); índice com tamanho diferente de 32 falha; mesmo índice no mesmo tenant dá `23505`; mesmo índice em outro tenant entra; vários usuários sem CPF entram; o tenant B não vê o índice do tenant A; `usuario_aud` não tem coluna `cpf%`; inserção sem as colunas de CPF continua funcionando.
- **Entrega.** Integrada no `boleto-migrations` antes do backend. A CI do backend usa a composite action `imagem-migracoes` fixada no SHA do commit da V3 ([Migrações do banco](../guias/migracoes.md)).

## Consequências

- O `modelo-de-dados.md` deixa de dizer "CPF entra na V2". O ADR 0025 recebe uma nota de consequência e a decisão dele não muda.
- Remover ou tornar `NOT NULL` uma dessas colunas no futuro exige duas migrações com um deploy entre elas.
- O `ddl-auto=validate` do backend precisa da V3 no schema de teste (`MIGRATIONS_CONTEXT` ou a imagem da CI).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Editar a V1 | Migração aplicada não se edita: o Flyway falha no checksum |
| Tabela separada `usuario_cpf` | Mais uma junção e mais uma política de RLS sem ganho: o CPF é atributo do usuário |
| Colunas `NOT NULL` | Quebra o backend anterior e o administrador inicial, que não tem CPF |
| `CREATE INDEX CONCURRENTLY` | Não roda na transação do Flyway |
| Guardar o CPF no `usuario_aud` | Copiaria o dado pessoal para a trilha, que não se apaga |
