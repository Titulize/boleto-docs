---
title: 'ADR 0050: Contexto de tenant, JWT e threads'
---
# ADR 0050: Contexto de tenant, JWT e threads
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O `ContextoTenant` guarda tenant efetivo, tenant de origem e usuário em um `ScopedValue` ([ADR 0037](./0037-contexto-de-tenant-por-transacao.md)). O [ADR 0030](./0030-manutencao-de-dados-e-origem-do-tenant.md) reservou ao Task 9 a tarefa de ligá-lo a partir do JWT.
## Decisão
- O `ContextoTenant` é ligado só por um filtro do módulo `auth`, depois da validação do JWT, com `tid`, `tor` e `sub`.
- Cabeçalhos do cliente (`X-Tenant-Id` e similares) são ignorados.
- Login e refresh rodam com `ContextoTenant.da(tenantDoEmail, SISTEMA)` apenas para ler o usuário. O tenant do e-mail vem da função `boleto.resolver_tenant_por_email`.
- Threads novas não herdam o `ScopedValue`. O `ContextoTaskDecorator` (em `shared.tenant`) captura e religa o contexto no executor `executorComContexto`.
- Uma regra do ArchUnit proíbe `@Async` fora de um executor com o decorator.
## Consequências
- O cliente nunca escolhe o tenant: só o JWT assinado define o contexto.
- Tarefas assíncronas precisam usar o executor decorado, senão falham por falta de contexto (e não gravam no tenant errado).
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Ler o tenant de um cabeçalho | O cliente poderia indicar o tenant de outra empresa |
| `InheritableThreadLocal` | Não combina com threads virtuais nem com `ScopedValue` |
