---
title: 'ADR 0051: Tokens de convite e de recuperação de senha'
---

# ADR 0051: Tokens de convite e de recuperação de senha

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

O [ADR 0012](./0012-autenticacao.md) prevê convite por e-mail e "esqueci minha senha", com token de 256 bits guardado só como hash. A V1 já tem a tabela `token_usuario` e a função `resolver_tenant_por_token` ([ADR 0025](./0025-modelo-de-dados-v1.md)). Os dois fluxos são públicos, então não podem revelar quais e-mails existem, e a troca de senha precisa derrubar as sessões abertas.

## Decisão

**Token.** 32 bytes de `SecureRandom`, em Base64url sem padding (43 caracteres). O banco guarda o SHA-256 dos bytes UTF-8 do texto (`token_hash`, 32 bytes). O texto do token nunca é gravado nem registrado em log.

| Tema | Regra |
|---|---|
| Validade do convite | 72 horas (`boleto.tokens.convite-ttl`) |
| Validade da recuperação | 30 minutos (`boleto.tokens.recuperacao-ttl`) |
| Pendentes | Cada emissão apaga os tokens pendentes (`usado_em` nulo) do mesmo usuário e finalidade. No máximo um pendente por usuário e finalidade |
| Uso único | Um só `UPDATE ... SET usado_em = :agora WHERE token_hash = :h AND usado_em IS NULL AND expira_em > :agora RETURNING usuario_id, finalidade`. Duas requisições com o mesmo token nunca consomem os dois |
| Relógio | `criado_em`, `expira_em` e `:agora` vêm do `Clock` do backend |
| Falha | Token inexistente, expirado, usado ou de usuário em situação que não aceita a finalidade: sempre 400 `TOKEN_SENHA_INVALIDO`, com o mesmo texto |

**Endpoints** ([Autenticação](../arquitetura/autenticacao.md)):

| Endpoint | Acesso | Resultado |
|---|---|---|
| `POST /usuarios` | `USUARIOS:INCLUIR` | Cria o usuário `CONVIDADO`, sem senha, e emite o convite. 201 |
| `POST /usuarios/{id}/convite` | `USUARIOS:ALTERAR` | Reenvia o convite, só para `CONVIDADO` (senão 409 `CONFLITO`). O convite anterior deixa de valer. 204 |
| `POST /auth/definir-senha` | pública | `{token, senha}`. Serve ao convite e à recuperação: o token define a finalidade. 204 |
| `POST /auth/esqueci-senha` | pública | `{email}`. Sempre 202 com a mensagem fixa "Se o e-mail estiver cadastrado, enviaremos as instruções." |

O tenant do `POST /usuarios` vem só do JWT. Um `tenantId` no corpo é ignorado.

**Quem recebe "esqueci".** Só usuário `ATIVO`. `BLOQUEADO`, `INATIVO` e `CONVIDADO` recebem a mesma resposta 202 e nenhum e-mail: recuperar senha não reativa conta, e quem foi convidado reenvia o convite pelo administrador.

**Neutralidade.** A resposta do "esqueci" tem o mesmo status, corpo e cabeçalhos (exceto `X-Trace-Id`) para e-mail existente, inexistente e em qualquer situação. O que difere (buscar o tenant, emitir o token, enviar o e-mail) roda em outra thread depois de responder (`@Async("executorComContexto")`), então o tempo também não distingue. E-mail com formato inválido continua 400 `VALIDACAO`, porque isso não revela existência.

**Limite por e-mail.** 3 pedidos de "esqueci" por 15 minutos por e-mail (`limite:esqueci:{sha256(email)}`, Bucket4j no Valkey). Acima disso a resposta continua 202 e nenhum token é emitido (sem 429, para não distinguir nada). O limite por IP do [ADR 0047](./0047-rate-limiting-e-bloqueio-de-conta.md) continua valendo e responde 429. Com o Valkey fora do ar, a resposta é 503 `SERVIDOR_INDISPONIVEL` para qualquer e-mail.

**Situação do usuário.** `CONVIDADO` vira `ATIVO` ao aceitar o convite, na mesma transação que grava o hash da senha. A recuperação mantém `ATIVO`. O fluxo não faz login: devolve 204 e a pessoa entra por `POST /auth/login`.

**Sessões.** Ao definir a senha, todas as sessões do usuário são revogadas. O `SessaoRepositorio` guarda o conjunto `sessoes-usuario:{usuarioId}` (um `sid` por login, TTL de 25 horas) e `revogarTodas` grava `sessao-revogada:{sid}` para cada um. A revogação roda dentro da transação, antes do commit: se o Valkey falhar, a transação desfaz e o token continua válido. O contador de falhas de login do e-mail também é zerado.

**Ator na auditoria.** Os fluxos públicos rodam com o tenant do token e o usuário "sistema". A revisão do Envers mostra o sistema na mudança `CONVIDADO` para `ATIVO`. A troca de senha em si não gera revisão (`senha_hash` fica fora da auditoria) e é registrada em log INFO só com o id do usuário.

**Módulos.** `auth` orquestra (`DefinirSenhaServico`, `RecuperacaoDeSenhaServico`). `usuarios` fornece `TokenUsuarioServico` e `ConviteServico`. `usuarios` não depende de `auth`.

**Erros novos:** `TOKEN_SENHA_INVALIDO` (400) e `SENHA_FRACA` (400), em [Erros da API](../arquitetura/erros-da-api.md).

## Consequências

- Quem lê o banco não consegue usar um convite, porque só existe o hash.
- Senha fraca não consome o token: tudo corre numa transação, e a exceção desfaz o `UPDATE`.
- A revogação de sessões depende do Valkey. Se ele cair no meio da troca, a troca falha e a pessoa tenta de novo.
- O índice `sessoes-usuario` acrescenta uma chave por usuário no Valkey, com TTL.
- O texto de erro igual para todas as falhas de token impede descobrir se um link já foi usado ou se expirou. A pessoa recebe a orientação de pedir um novo.
- Tokens expirados continuam na tabela. A limpeza fica para o Task 15 (retenção, ver [inventário LGPD](../arquitetura/inventario-lgpd.md)).
- O relógio do banco (`now()` em `resolver_tenant_por_token`) e o do backend (`Clock`) precisam estar próximos. Nos testes, o relógio só avança.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Senha temporária enviada ao usuário | A senha circula em texto e fica no e-mail |
| Validade longa para a recuperação | Um e-mail antigo na caixa de entrada seria uma credencial |
| 429 quando o limite por e-mail estoura | Revelaria que o e-mail recebeu pedidos anteriores |
| Login automático depois de definir a senha | Mistura dois fluxos e deixaria uma sessão nascer de um token de e-mail |
| Revogar só a sessão atual | Quem roubou a senha antiga continuaria com a sessão aberta |
| Enviar o e-mail dentro da requisição | O tempo de resposta distinguiria e-mail existente do inexistente |
