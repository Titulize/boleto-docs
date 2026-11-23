---
title: 'ADR 0012: Autenticação com JWT e convite por e-mail'
---

# ADR 0012: Autenticação com JWT e convite por e-mail

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Os usuários são cadastrados manualmente pelo administrador da empresa gestora. Não há cadastro aberto. É preciso permitir recuperar a senha.

## Decisão

- Spring Security com JWT de acesso de vida curta e refresh token com rotação, guardado no Valkey. Logout coloca o token em uma blacklist.
- O administrador cadastra o usuário e o sistema envia um convite por e-mail para o próprio usuário definir a senha. Não existe senha temporária.
- "Esqueci minha senha" usa o mesmo mecanismo de token, com expiração mais curta e resposta neutra, que não revela se o e-mail existe.
- O token é aleatório de 256 bits. O banco guarda só o hash, com expiração e uso único.
- Senhas com Argon2id.
- E-mails por SMTP: Mailpit em desenvolvimento e Amazon SES depois.

## Consequências

- Sem dependência de provedor externo de identidade e sem custo.
- A segurança do fluxo passa a ser responsabilidade do código, por isso há testes de expiração, reuso e enumeração de e-mails.
- Cognito ou Keycloak podem substituir a solução depois, atrás da mesma interface.

**Nota (2026-11-23):** o Task 9 detalhou esta decisão sem alterá-la: algoritmo e chave no [ADR 0044](./0044-jwt-es256-e-chave.md), claims e tempos no [ADR 0045](./0045-claims-tempos-e-sessao-diaria.md), refresh e blacklist no [ADR 0046](./0046-refresh-e-blacklist-no-valkey.md) e administrador inicial no [ADR 0049](./0049-administrador-inicial.md). O convite por e-mail e o esqueci minha senha continuam pendentes.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Keycloak ou Cognito | Dependência e integração com os perfis de acesso sem necessidade agora |
| Senha temporária enviada pelo administrador | A senha circula entre pessoas |
