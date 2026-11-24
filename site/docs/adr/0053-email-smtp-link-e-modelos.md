---
title: 'ADR 0053: E-mail por SMTP, link e modelos'
---

# ADR 0053: E-mail por SMTP, link e modelos

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

O convite e a recuperação de senha ([ADR 0051](./0051-tokens-de-convite-e-recuperacao-de-senha.md)) enviam um link por e-mail. Em desenvolvimento o Mailpit captura tudo. Na AWS será o Amazon SES, que também fala SMTP. O envio não pode revelar quais e-mails existem (pelo tempo de resposta) nem quebrar o cadastro quando o SMTP falha.

## Decisão

**SMTP.** `spring-boot-starter-mail` (versão do BOM do Spring Boot, sem entrada no `versions.toml`). Configuração por `SPRING_MAIL_HOST`, `SPRING_MAIL_PORT`, `SPRING_MAIL_USERNAME` e `SPRING_MAIL_PASSWORD`. Sem variáveis, usa `localhost:1025` sem autenticação (o Mailpit). Timeouts de conexão, leitura e escrita de 5 segundos. O SES entra depois, só por variáveis.

**Saúde.** `management.health.mail.enabled=false`: SMTP fora do ar não derruba o health nem o healthcheck do Compose.

**Envio assíncrono.** O `usuarios` publica o evento `TokenDeUsuarioEmitido` (usuário, nome, e-mail, finalidade, token e validade; o `toString` não mostra nada disso). O ouvinte `auth.EnvioDeEmailDeSenha` usa `@TransactionalEventListener(phase = AFTER_COMMIT)` e `@Async("executorComContexto")`. Com isso:

- nada é enviado se a transação desfizer;
- latência e falha do SMTP não quebram nem desfazem o cadastro;
- o tempo do "esqueci minha senha" não distingue e-mail existente do inexistente;
- o `ContextoTenant` chega à thread nova pelo `ContextoTaskDecorator` ([ADR 0050](./0050-contexto-de-tenant-jwt-e-threads.md)), e o ouvinte lê o nome da empresa gestora com ele.

**Falha de envio.** Log ERROR com a classe da exceção e o id do usuário. A mensagem do JavaMail pode trazer o endereço, então não vai para o log. Sem retry automático: o administrador reenvia o convite, e quem esqueceu a senha pede de novo. Métrica de falhas fica para o Task 11.

**Link.** O token vai no fragmento da URL, que o navegador não envia ao servidor nem no `Referer`:

| Finalidade | Link |
|---|---|
| Convite | `{BOLETO_APP_URL_BASE}/definir-senha#token={token}` |
| Recuperação | `{BOLETO_APP_URL_BASE}/redefinir-senha#token={token}` |

`BOLETO_APP_URL_BASE` (`boleto.app.url-base`) não tem barra final e vale `http://localhost:4200` em dev. Fora de `localhost` o backend exige `https` e não sobe sem ele. As duas rotas pertencem ao frontend (Task 13). Não há página provisória no backend: até lá o token é copiado do link no Mailpit e enviado ao `POST /auth/definir-senha`.

**Remetente.** `BOLETO_EMAIL_REMETENTE`, padrão `Plataforma de Boletos <nao-responda@boleto.test>`. Em produção, um domínio verificado no SES.

**Assuntos (fixos, sem dado pessoal).** Convite: "Você foi convidado para a Plataforma de Boletos". Recuperação: "Redefinição de senha da Plataforma de Boletos".

**Modelo.** `multipart/alternative` com texto e HTML, em `src/main/resources/email/` (`convite.txt`, `convite.html`, `recuperacao.txt`, `recuperacao.html`). Um renderizador pequeno troca `{{campo}}` e escapa o HTML. Sem Thymeleaf. O conteúdo tem a saudação com o primeiro nome, o nome da empresa gestora (só no convite), o link por extenso, a validade ("72 horas" ou "30 minutos") e, na recuperação, "se você não pediu, ignore".

**Injeção de cabeçalho.** O destinatário é validado com `InternetAddress(email, true)`, e CR e LF são recusados antes. O cadastro também recusa e-mail com espaços ou quebras de linha (400 `VALIDACAO`).

## Consequências

- O e-mail do convite pode não chegar sem que ninguém seja avisado além do log. O administrador vê o usuário `CONVIDADO` e reenvia.
- O link só abre uma página quando o frontend existir (Task 13).
- Trocar o SMTP por SES não muda código, só variáveis (autenticação e STARTTLS).
- Os testes automatizados enviam ao Mailpit real (imagem do `versions.toml`) e leem a API HTTP dele. Por isso o alvo `backend` da sincronização passou a entregar `MAILPIT_IMAGE` (tag `v0.6.0`).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Token na query string (`?token=`) | Vai ao servidor, a logs de proxy e ao `Referer` |
| Envio dentro da requisição | O tempo de resposta revela se o e-mail existe, e a falha do SMTP desfaz o cadastro |
| Thymeleaf para os modelos | Dependência e configuração a mais para quatro arquivos |
| Página provisória de definir senha no backend | A rota pertence ao frontend; duplicaria a tela do Task 13 |
| SDK do Amazon SES | SMTP serve a dev e à AWS com o mesmo código |
