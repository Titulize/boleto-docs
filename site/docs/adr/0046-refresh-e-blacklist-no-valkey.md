---
title: 'ADR 0046: Refresh token e blacklist no Valkey'
---
# ADR 0046: Refresh token e blacklist no Valkey
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O [ADR 0012](./0012-autenticacao.md) pede refresh com rotação no Valkey e blacklist no logout. Falta definir o formato, as chaves, a atomicidade da rotação e o que fazer quando o Valkey cai.
## Decisão
- O refresh token é opaco, com 256 bits de `SecureRandom` em base64url. O Valkey guarda só o SHA-256 dele.
- Chaves do Valkey:

| Chave | Valor | TTL |
|---|---|---|
| `refresh:{hash}` | `sid\|usuarioId` | validade do refresh |
| `refresh-usado:{hash}` | `sid` | o que resta da sessão |
| `sessao-revogada:{sid}` | `1` | o que resta da sessão |

- `sessao-revogada:{sid}` é a blacklist do logout e do reuso. Todo access token é validado contra ela.
- A rotação é um script Lua atômico: lê e apaga `refresh:{hash}`, grava `refresh-usado:{hash}` e grava o novo `refresh:{novo}`.
- Se `refresh:{hash}` não existe e `refresh-usado:{hash}` existe, é **reuso**. O script devolve o `sid`, a sessão inteira é revogada e a resposta é 401 `REFRESH_REUTILIZADO`.
- **Valkey fora do ar: falha fechada.** A resposta é 503 `SERVIDOR_INDISPONIVEL`. O backend nunca aceita um token sem consultar a blacklist.
- O refresh viaja no corpo JSON. O cookie HttpOnly fica como evolução, porque exige CSRF e CORS no frontend.
- **Pendência do frontend (Tasks 12 e 13):** ao carregar ou recarregar a página, o Angular chama `POST /auth/refresh` para obter um novo access. Isso exige guardar o refresh entre recarregamentos (sessionStorage ou cookie HttpOnly). A escolha é do frontend e reabre a evolução para cookie. O backend não muda por isso.
## Consequências
- Um vazamento do Valkey não revela refresh tokens utilizáveis, só hashes.
- O logout e a detecção de reuso valem imediatamente em todas as instâncias do backend.
- O Valkey passa a ser dependência de disponibilidade da API autenticada.
- Descoberto na implementação: o valor de `refresh:{hash}` precisou levar também o tenant de origem e o fim da sessão (`sid|usuarioId|tenantOrigem|sessaoExpiraEm`), para o refresh não consultar o banco. O script também confere `sessao-revogada:{sid}` e o fim da sessão, e no reuso já grava `sessao-revogada:{sid}`. No logout o TTL de `sessao-revogada:{sid}` é fixo em 25 horas, maior que qualquer sessão. Detalhes em [Autenticação e autorização](../arquitetura/autenticacao.md#chaves-do-valkey).
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Refresh em tabela do PostgreSQL | Cada renovação gravaria no banco, e o Valkey já é a infraestrutura de sessão do [ADR 0012](./0012-autenticacao.md) |
| Falha aberta com o Valkey fora do ar | Aceitaria token já revogado |
| Rotação sem script (ler e depois apagar) | Dois refreshs simultâneos poderiam passar |
