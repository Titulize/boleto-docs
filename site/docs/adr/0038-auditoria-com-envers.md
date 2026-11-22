---
title: 'ADR 0038: Auditoria com Envers, revisão customizada e diff'
---

# ADR 0038: Auditoria com Envers, revisão customizada e diff

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

O [ADR 0007](./0007-auditoria-envers.md) escolheu o Hibernate Envers, e a V1 criou `revinfo` e as tabelas `_aud` ([ADR 0025](./0025-modelo-de-dados-v1.md), que pediu ao Task 8 conferir o desenho contra o Envers real). Faltava mapear a revisão com usuário, tenant e origem ([ADR 0030](./0030-manutencao-de-dados-e-origem-do-tenant.md)) e calcular o diff mostrado na tela.

## Decisão

**Dependência.** `org.hibernate.orm:hibernate-envers` entra no `build.gradle.kts` do backend sem versão. A versão vem do BOM do Spring Boot 4.1.3, já pinado no `versions.toml`, que por convenção não repete as bibliotecas do BOM. O mesmo vale para `spring-boot-starter-validation`.

**Revisão customizada.** `RevisaoAuditoria` (tabela `revinfo`, módulo `auditoria`): `rev` com `@SequenceGenerator(sequenceName = "revinfo_seq", allocationSize = 50)`, `revtstmp` em milissegundos desde 1970, `usuario_id`, `tenant_id` e `tenant_origem_id`. `RevisaoAuditoriaListener` lê o `ContextoTenant` ([ADR 0037](./0037-contexto-de-tenant-por-transacao.md)). Sem contexto, a escrita auditada falha com erro claro. O `tenant_origem_id` só é gravado quando difere do efetivo.

**Configuração.** `audit_table_suffix=_aud`, `revision_field_name=rev`, `revision_type_field_name=revtype` e `hibernate.default_schema=boleto`. O `ddl-auto=validate` aceita as entidades, a `revinfo_seq` com incremento 50 e `revtype smallint`: o desenho da V1 não precisou de correção.

**Entidades auditadas.** `EmpresaGestora` e `Usuario`. As tabelas `perfil*` e `usuario_perfil` entram com suas entidades no Task 9. `criado_em`, `atualizado_em` e `versao` são `@NotAudited` (não existem nas `_aud`). `senha_hash` não é mapeada nesta fase, e `usuario_aud` não tem coluna de senha. A `empresa_gestora_aud` recebe o `tenant_id` por gatilho ([ADR 0042](./0042-v2-tenant-da-auditoria-da-empresa.md)).

**Diff.** `ConsultaAuditoria.historico(Class, id)` usa `forRevisionsOfEntity` e compara retratos consecutivos por reflexão sobre os campos auditados, devolvendo `RevisaoAuditada` (número, instante, usuário, tenant, origem, tipo e uma lista de `Alteracao(campo, anterior, novo)`). Ignora campos estáticos, `@NotAudited`, `id` e `tenantId`. É só serviço: não há endpoint, porque ainda não há autenticação.

## Consequências

- O `AuditoriaUsuarioTest` cobre inclusão e alteração com valor anterior, novo e horário, usuário e tenant da revisão, origem quando a plataforma atua em outra empresa, rollback sem revisão, falha sem contexto, isolamento do histórico entre tenants e a V2 em `empresa_gestora_aud`. Mudança só de `versao` ou `atualizado_em` não gera revisão.
- Sem teste: exclusão (`DEL`) e concorrência com `@Version`.
- O diff usa `getDeclaredFields` e não enxerga campos de superclasse. Entidade nova com herança exige ajustar `DiffAuditoria`.
- A `revinfo_seq` com incremento 50 reserva faixas de números por instância: os números de revisão têm lacunas.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Revisão padrão do Envers (`revinfo` com `rev` e `revtstmp`) | Não grava usuário, tenant nem origem |
| Auditoria por gatilho no banco | O banco não conhece o usuário autenticado |
| Calcular o diff na tela | Duplicaria a regra em cada cliente |
| Auditar `perfil*` agora | As entidades ainda não existem (Task 9) |
