---
title: 'ADR 0042: V2, tenant da auditoria da empresa gestora'
---

# ADR 0042: V2, tenant da auditoria da empresa gestora

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

A `empresa_gestora` não tem coluna `tenant_id`: o próprio `id` é o tenant. A `empresa_gestora_aud.tenant_id` é `NOT NULL` e tem RLS por essa coluna, mas o Envers só grava as colunas da entidade, então ele não consegue preenchê-la. A V1 ([ADR 0025](./0025-modelo-de-dados-v1.md)) não previu isso, e o `usuario_aud` não tem o problema (a entidade `Usuario` tem `@TenantId`).

## Decisão

A migração `sql/V2__auditoria_empresa_gestora_tenant.sql` do `boleto-migrations` cria o gatilho `BEFORE INSERT` `empresa_gestora_aud_definir_tenant` em `boleto.empresa_gestora_aud`, que faz `new.tenant_id := new.id`.

- A função pertence à `boleto_owner`, com `SET ROLE boleto_owner` no começo e `RESET ROLE` no fim, e `revoke all ... from public`, como a V1 fez com `validar_perfil_tela_permissao`.
- Define `lock_timeout` e `statement_timeout` e os restaura no fim: o lint (Squawk) recusa a migração sem eles (`require-lock-timeout` e `require-statement-timeout`).
- **Expand.** É só acréscimo e é compatível com o backend anterior ([padrão do projeto](../guias/padrao-do-projeto.md), regra expand/contract). A V1 não foi editada.
- O gatilho sobrescreve qualquer `tenant_id` informado pelo chamador.

## Consequências

- O `tests/sql/08d_aud_empresa_tenant.sql` confere três casos: a origem da plataforma grava a auditoria sem informar o `tenant_id` e o gatilho o preenche; um `tenant_id` informado é sobrescrito; outro tenant sem origem da plataforma é recusado pela RLS (SQLSTATE 42501). A RLS por tenant deixa a própria empresa gravar a própria auditoria.
- `tests/08c_cnpj_configuravel.sh` deixou de fixar `= "1"` migração e passou a comparar com a quantidade de arquivos `V*.sql`.
- O backend só passa a gravar a auditoria da empresa com a V2 aplicada. A V2 chega ao `boleto-dev` no próximo `docker compose up -d`, sem apagar dados. Nenhuma V2 foi aplicada no `boleto-dev` durante o Task 8.
- Não há outra mudança de coluna: `usuario_aud` já tem as colunas que o `Usuario` audita.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Adicionar coluna `tenant_id` em `empresa_gestora` | Duplica o `id` e muda a tabela base sem necessidade |
| Preencher no backend com um listener | O Envers grava a `_aud` por conta própria, e o backend não tem como incluir uma coluna que a entidade não tem |
| Tornar `tenant_id` anulável na `_aud` | Quebra a política de RLS por tenant |
| Editar a V1 | Migração aplicada não se edita |
