---
title: 'ADR 0037: Contexto de tenant e app.tenant_id por transação'
---

# ADR 0037: Contexto de tenant e `app.tenant_id` por transação

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

O [ADR 0008](./0008-multitenancy.md) define duas camadas de isolamento (`@TenantId` do Hibernate e RLS do PostgreSQL) e o [ADR 0030](./0030-manutencao-de-dados-e-origem-do-tenant.md) deixa para o backend o contrato de que `app.tenant_id` e `app.tenant_origem_id` só nascem de um usuário autenticado. A `boleto_app` consegue alterar essas variáveis, então o banco não defende sozinho esse contrato. Ainda não existe autenticação (Task 9).

## Decisão

**`ContextoTenant`.** Um record em `shared.tenant` com `tenantId` (efetivo), `tenantOrigemId` (tenant do usuário autenticado) e `usuarioId`, os três nunca nulos. Fica num `ScopedValue` (final no Java 25): some ao sair do escopo e não vaza entre threads de pool. `da(tenant, usuario)` cria o contexto próprio e `assumindo(origem, efetivo, usuario)` o contexto da plataforma atuando em outra empresa.

**Só o servidor liga o contexto.** Nenhum controller, filtro ou cabeçalho lê tenant ou usuário do cliente: o cabeçalho `X-Tenant-Id` é ignorado. Uma regra do ArchUnit (`contextoTenantSoLigadoPeloAuth`) permite chamar `ContextoTenant.executar` e `chamar` só aos pacotes `..auth..` e `..shared.tenant..`. Os testes ficam fora do ArchUnit. O Task 9 só liga o JWT validado ao `ContextoTenant.executar`.

**`@TenantId` estrito.** `TenantIdResolver` implementa `CurrentTenantIdentifierResolver<UUID>` e lança `ContextoTenantAusenteException` sem contexto. O Hibernate 7 já recusa abrir sessão sem tenant. O resolver é registrado por nome em `spring.jpa.properties.hibernate.tenant_identifier_resolver`.

**`app.tenant_id` por transação.** `TenantJpaDialect` estende `HibernateJpaDialect` e, logo depois do `beginTransaction`, executa:

```sql
select set_config('app.tenant_id', ?, true), set_config('app.tenant_origem_id', ?, true)
```

`set_config(..., true)` equivale a `SET LOCAL`, mas aceita parâmetro de bind (o `SET LOCAL` literal exigiria concatenar o valor). O valor some no commit ou no rollback, então não vaza entre conexões do pool. Sem contexto a transação nem começa (falha fechada), e fora de uma transação o banco devolve 0 linhas.

**Registro do dialeto.** Um `BeanPostProcessor` troca o dialeto do `JpaTransactionManager` depois da inicialização. A primeira tentativa, com `TransactionManagerCustomizer`, foi desfeita porque o `JpaTransactionManager` copia o dialeto da fábrica de entidades ao recebê-la.

**Origem.** `tenantOrigemId` é sempre o tenant do usuário autenticado, porque as políticas de `empresa_gestora` e `tela` dependem dele mesmo sem "assumir empresa". A revisão de auditoria só grava `tenant_origem_id` quando ele difere do efetivo ([ADR 0038](./0038-auditoria-com-envers.md)).

**`EmpresaGestora` sem `@TenantId`.** O `id` dela é o tenant e não há coluna `tenant_id`: o isolamento dela é só a RLS.

## Consequências

- Os dois mecanismos funcionam de forma independente. Os testes `IsolamentoPorTenantTest` desligam o filtro do Hibernate e a RLS ainda devolve só o tenant certo. Com `maximum-pool-size=1`, `current_setting('app.tenant_id', true)` fica vazio depois do commit e do rollback.
- Regressão provada: sem o `set_config` no dialeto, 4 casos do `IsolamentoPorTenantTest` falham.
- `@Async` e threads virtuais não herdam o `ScopedValue` e falham fechado. O Task 9 precisa propagar o contexto de forma explícita onde usar essas threads.
- Não há teste de `REQUIRES_NEW` com outro contexto nem de transação `readOnly`. Ficam como pendência.
- O teste do cabeçalho `X-Tenant-Id` usa uma rota de teste. Deve ser repetido nos controllers reais do Task 9.
- Cada transação ganha uma ida ao banco para o `set_config`.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| `ThreadLocal` ou MDC para o contexto | Vaza entre requisições em threads de pool se alguém esquecer de limpar |
| `SET LOCAL` literal | Não aceita bind e obriga a concatenar o valor no SQL |
| `set_config` por sessão (`false`) | O valor ficaria na conexão devolvida ao pool e vazaria para outro tenant |
| Tenant lido de cabeçalho ou parâmetro | Permite ao cliente escolher o tenant |
| `TransactionManagerCustomizer` | O dialeto era sobrescrito pelo `JpaTransactionManager` |
| Resolver permissivo (tenant padrão ou nulo) | Uma consulta sem contexto teria efeito silencioso |
