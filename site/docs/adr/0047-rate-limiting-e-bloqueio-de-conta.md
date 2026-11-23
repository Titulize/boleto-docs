---
title: 'ADR 0047: Limite de requisições e bloqueio de conta'
---
# ADR 0047: Limite de requisições e bloqueio de conta
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O [ADR 0013](./0013-rate-limiting.md) escolheu Bucket4j com Valkey. O Task 9 define os limites do login e o bloqueio por tentativas erradas, sem alterar o schema do banco.
## Decisão
- Bucket4j com Lettuce no Valkey.
- **Por IP:** 30 requisições por minuto em `/auth/**` (capacidade 30, recarga intervalar de 30 por minuto).
- **Por usuário:** 10 tentativas de login por minuto, por `sha256(email)`.
- **Bloqueio de conta:** o contador `login-falhas:{sha256(email)}` no Valkey usa INCR, com TTL fixo de 15 minutos definido na primeira falha. Com 5 falhas, a tentativa seguinte (a 6ª) devolve 429 `LIMITE_EXCEDIDO` com `Retry-After`, sem verificar a senha. O login correto zera o contador.
- O bloqueio vale também para e-mail inexistente, para não permitir enumeração de contas.
- Não há migração V3 nem revisão de auditoria por tentativa. `situacao = BLOQUEADO` continua só para bloqueio administrativo e responde 401 genérico.
- **IP do cliente:** o `remoteAddr`. O `X-Forwarded-For` só vale se o `remoteAddr` estiver em `boleto.seguranca.proxies-confiaveis` (lista de CIDR, vazia por padrão). Nesse caso, usa a entrada mais à direita que não seja proxy confiável.
## Consequências
- Quem erra a senha 5 vezes espera até 15 minutos, e um atacante pode bloquear a conta de outra pessoa errando de propósito. O limite por IP reduz esse risco, mas não o elimina.
- O contador some se o Valkey for apagado. Aceito: o Valkey fora do ar já falha fechado ([ADR 0046](./0046-refresh-e-blacklist-no-valkey.md)).
- O [ADR 0013](./0013-rate-limiting.md) previa configurar o cabeçalho confiável com a infraestrutura; esta decisão fixa a regra no backend.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Colunas de tentativas e bloqueio em `usuario` (V3) | Escritas no banco a cada tentativa errada e auditoria ruidosa |
| Bloquear a conta no banco com `BLOQUEADO` | Exigiria desbloqueio manual; o bloqueio por tentativa deve expirar sozinho |
| Confiar sempre no `X-Forwarded-For` | Qualquer cliente forjaria o IP e escaparia do limite |
