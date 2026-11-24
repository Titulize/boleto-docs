---
sidebar_position: 6
title: Convite e senha
---

# Convite de usuário e "esqueci minha senha"

Como convidar um usuário, ler o e-mail no Mailpit e definir ou recuperar a senha no ambiente de desenvolvimento. Decisões nos ADRs [0051](../adr/0051-tokens-de-convite-e-recuperacao-de-senha.md), [0052](../adr/0052-politica-de-senha.md) e [0053](../adr/0053-email-smtp-link-e-modelos.md). O desenho dos fluxos está em [Autenticação e autorização](../arquitetura/autenticacao.md).

## Antes de começar

Com o Compose no ar (`docker compose up -d --build`), o backend espera o Mailpit e envia os e-mails a ele. A caixa de entrada de dev é `http://localhost:8025`. O administrador inicial é `admin@boleto.test` com a senha de dev do `docker-compose.yml`.

Os exemplos usam `curl` no Git Bash ou no Linux. No PowerShell, use `curl.exe` e aspas simples no corpo. Troque `localhost:8080` se mudou `BACKEND_PORT`.

## 1. Entrar como administrador

```bash
curl -s -X POST http://localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@boleto.test","senha":"<senha de dev do docker-compose.yml>"}'
```

Guarde o `accessToken` da resposta em `ACCESS`.

## 2. Convidar um usuário

O perfil `Administrador da plataforma` tem o id `00000000-0000-7000-8000-000000000101`. O CPF é opcional e deve ser um CPF de teste válido (com ou sem pontuação). Use um e-mail de teste, como `convidado@boleto.test`.

```bash
curl -s -X POST http://localhost:8080/usuarios \
  -H "Authorization: Bearer $ACCESS" -H 'Content-Type: application/json' \
  -d '{"nome":"Fulana de Tal","email":"convidado@boleto.test","cpf":"<CPF de teste>","perfilIds":["00000000-0000-7000-8000-000000000101"]}'
```

Resposta: 201 com `situacao` `CONVIDADO` e `cpfMascarado` (por exemplo `***.456.789-**`). O CPF nunca volta em claro. E-mail ou CPF já cadastrados dão 409 `CONFLITO`; perfil de outro tenant dá 404 `NAO_ENCONTRADO`. A rota exige `USUARIOS:INCLUIR`.

## 3. Ler o e-mail no Mailpit

Abra `http://localhost:8025` e a mensagem "Você foi convidado para a Plataforma de Boletos". O link tem este formato:

```text
http://localhost:4200/definir-senha#token=<43 caracteres>
```

O token vai depois do `#` (fragmento). Copie só o texto depois de `token=`. Pela linha de comando:

```bash
curl -s http://localhost:8025/api/v1/messages              # lista (anote o ID da mensagem)
curl -s http://localhost:8025/api/v1/message/<ID>          # texto e HTML
```

Ainda não existe a tela do link: ela é do frontend (Task 13). Por isso o token é copiado do e-mail e enviado ao backend, no Swagger (`http://localhost:8080/swagger-ui.html`) ou no `curl`.

## 4. Definir a senha

```bash
curl -s -i -X POST http://localhost:8080/auth/definir-senha \
  -H 'Content-Type: application/json' \
  -d '{"token":"<token do e-mail>","senha":"<senha com 12 caracteres ou mais>"}'
```

- 204: a senha foi definida e o usuário passou a `ATIVO`. Entre por `POST /auth/login`. O fluxo não faz login sozinho.
- 400 `TOKEN_SENHA_INVALIDO`: o link não existe, expirou (72 horas), já foi usado ou o usuário não está `CONVIDADO`. Repetir a chamada com o mesmo token dá este erro.
- 400 `SENHA_FRACA`: a senha não cumpre a [política](../adr/0052-politica-de-senha.md). O token continua válido: corrija a senha e envie de novo.

## 5. Reenviar o convite

Se o link expirou ou o e-mail não chegou, o administrador reenvia (exige `USUARIOS:ALTERAR`). O convite anterior deixa de valer.

```bash
curl -s -i -X POST http://localhost:8080/usuarios/<id do usuário>/convite \
  -H "Authorization: Bearer $ACCESS"
```

204 em caso de sucesso. Para usuário que não é `CONVIDADO`, 409 `CONFLITO`.

## 6. Esqueci minha senha

```bash
curl -s -i -X POST http://localhost:8080/auth/esqueci-senha \
  -H 'Content-Type: application/json' -d '{"email":"convidado@boleto.test"}'
```

A resposta é sempre 202 com `{"mensagem":"Se o e-mail estiver cadastrado, enviaremos as instruções."}`, exista ou não o e-mail. Só usuário `ATIVO` recebe a mensagem "Redefinição de senha da Plataforma de Boletos", com link `.../redefinir-senha#token=...` válido por 30 minutos. O pedido é limitado a 3 por 15 minutos por e-mail: acima disso a resposta continua 202 e nenhum e-mail sai. Para redefinir, envie o token a `POST /auth/definir-senha`, como no passo 4.

Ao redefinir, todas as sessões abertas do usuário caem: o `accessToken` e o `refreshToken` antigos passam a dar 401.

## Contrato das rotas do frontend

O Task 13 implementa estas rotas. O backend já gera os links para elas:

| Rota | Quando | Como ler o token |
|---|---|---|
| `/definir-senha` | Convite | `location.hash`, formato `#token=<token>` |
| `/redefinir-senha` | Recuperação | `location.hash`, formato `#token=<token>` |

O frontend lê o token do fragmento, apaga o fragmento do histórico (`history.replaceState`) e envia `{token, senha}` a `POST /auth/definir-senha`. O token nunca vai em query string.

## Problemas conhecidos

- **O e-mail não chegou:** olhe `docker compose logs backend`. Falha de envio aparece como ERROR com a classe da exceção e o id do usuário, sem o endereço. Confirme que o `mailpit` está saudável (`docker compose ps`). O backend não tenta de novo: reenvie o convite ou peça de novo o "esqueci".
- **429 em `/auth/**`:** o limite por IP é de 30 requisições por minuto. Espere um minuto, ou limpe o Valkey de dev (`docker compose exec valkey valkey-cli -a valkey_dev --no-auth-warning FLUSHALL`).
- **O backend não sobe e fala de chaves de dados pessoais:** veja [Chaves de CPF](./chaves-de-cpf.md).
- **O link do e-mail aponta para `localhost:4200` e nada abre:** é esperado até o Task 13. Use o token no Swagger ou no `curl`.
