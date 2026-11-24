---
sidebar_position: 10
title: 'Task 10: Convite e "esqueci minha senha"'
---

# Task 10: Convite de usuário e "esqueci minha senha"

- **Situação:** Em andamento
- **Início:** 2026-11-24
- **Última atualização:** 2026-11-24
- **Repositórios:** `boleto-docs`, `boleto-migrations` (V3), `boleto-backend`

## Objetivo

O administrador convida um usuário por e-mail, a pessoa define a senha pelo link, e quem esqueceu a senha recupera o acesso por e-mail. Entram junto o CPF cifrado do usuário, a máscara de dados pessoais nos logs e o envio de e-mail por SMTP. Demonstração: convite, e-mail no Mailpit, senha definida e login.

## Entregue

`boleto-docs`:

- Tag `v0.6.0` (PR [#19](https://github.com/Titulize/boleto-docs/pull/19), `7a74113`): o alvo `backend` da sincronização passou a entregar `MAILPIT_IMAGE`, que os testes de e-mail do backend usam. Nenhuma biblioteca Java nova entrou no `versions.toml`.
- ADRs [0051](../adr/0051-tokens-de-convite-e-recuperacao-de-senha.md) (tokens e fluxos), [0052](../adr/0052-politica-de-senha.md) (política de senha), [0053](../adr/0053-email-smtp-link-e-modelos.md) (e-mail, link e modelos), [0054](../adr/0054-cpf-criptografado-e-blind-index.md) (CPF cifrado), [0055](../adr/0055-mascara-de-dados-pessoais-nos-logs.md) (máscara nos logs) e [0056](../adr/0056-v3-cpf-do-usuario.md) (V3), com o índice atualizado.
- Notas de consequência, sem mudar decisão, nos ADRs [0012](../adr/0012-autenticacao.md), [0015](../adr/0015-lgpd.md), [0025](../adr/0025-modelo-de-dados-v1.md) ("CPF na V2" passou a V3), [0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md) (validação do wrapper) e [0045](../adr/0045-claims-tempos-e-sessao-diaria.md) (fuso confirmado).
- Páginas novas: [Inventário LGPD](../arquitetura/inventario-lgpd.md), [Convite e senha](../guias/convite-e-senha.md) e [Chaves de CPF](../guias/chaves-de-cpf.md).
- Páginas ajustadas: [Autenticação e autorização](../arquitetura/autenticacao.md) (quatro endpoints, dois diagramas, chaves do Valkey, variáveis), [Modelo de dados](../arquitetura/modelo-de-dados.md) (V3, colunas de CPF), [Erros da API](../arquitetura/erros-da-api.md) (`TOKEN_SENHA_INVALIDO` e `SENHA_FRACA`), [Módulos do backend](../arquitetura/modulos-backend.md), [Containers](../arquitetura/containers.md), [Migrações do banco](../guias/migracoes.md) e [Compose de desenvolvimento](../guias/compose-dev.md).
- `docker-compose.yml`: o `backend` espera o `mailpit` saudável e recebe `SPRING_MAIL_*`, `BOLETO_APP_URL_BASE`, `BOLETO_EMAIL_REMETENTE` e as chaves de CPF de desenvolvimento (constantes públicas `DEV-ONLY-`, sem a chave efêmera). `.env.example` e `scripts/compose.test.mjs` acompanham, e o teste recusa qualquer chave de CPF do Compose que não seja a constante de dev.

`boleto-migrations`: V3 `V3__cpf_do_usuario.sql` e o teste `tests/sql/08e_cpf_usuario.sql`, integrados pelo [PR #7](https://github.com/Titulize/boleto-migrations/pull/7) (squash `ba99f16`).

`boleto-backend` (branch `feat/task-10-convite-senha`, ainda sem PR): `POST /usuarios`, `POST /usuarios/{id}/convite`, `POST /auth/definir-senha` e `POST /auth/esqueci-senha`, `shared.pii`, `shared.email`, `shared.log.MascaraDeDados`, `PoliticaDeSenha`, `TokenUsuarioServico` e o ouvinte de e-mail em `auth`. Commits `2be8e0d` (CI: imagem de migração com a V3, `MAILPIT_IMAGE` no cache) e `c744e3e` (código, testes e README).

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| V3 e testes de isolamento | CI do PR #7 do `boleto-migrations` (run 45322947449) e da `main` (run 45323226848, `ba99f16`) | passou |
| Versões (`v0.6.0`) | CI e `Documentação` do PR #19 e da `main` do `boleto-docs` | passou |
| Backend, local, em `c744e3e` | `.\gradlew.bat --no-daemon spotlessCheck check` com `MIGRATIONS_CONTEXT` na `main` do `boleto-migrations` (V3) | 207 testes, 0 falhas; Jacoco 92,3% das linhas (mínimo 80%) |
| Imagem e versões do backend | `docker build -t boleto-backend:ci .` e `node .platform/sync-versions.mjs check --remote` | passaram |
| Scripts do `boleto-docs` | `npm run validate`, `npm run sync:check`, `npm test` (44 testes) | passaram |
| Compose | `docker compose config -q` | passou |
| Site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | ver o histórico (rodado a cada commit da documentação) |
| Commits | `npx commitlint --from origin/main --to HEAD` | ver o histórico |

**Ainda não verificado:**

- **Demonstração do plano** (login, `POST /usuarios`, e-mail no Mailpit, `definir-senha`, login, "esqueci", sessões revogadas e conferência de bytes no banco): não executada. A saída vai para `.agents/tasks/task-10/demo.md`.
- **CI do PR do backend:** o PR ainda não existe. A action `imagem-migracoes` com o SHA da V3 só roda no PR.
- **`docker compose up -d --build` com o Compose alterado:** só `docker compose config` e os testes de texto rodaram. A subida do backend com o `mailpit` e as chaves de dev sai com a demonstração.
- **Envio por SES real**, link abrindo uma página do frontend (as rotas são do Task 13), rotação de chave de CPF com dados reais e limpeza de tokens expirados.

## Falhas e correções

- **Teste do backend (corrigido antes do commit):** `DefinirSenhaIT` exigia que a mensagem de senha fraca não citasse o exemplo `123456789012`, que a própria regra de sequência cita. O teste foi corrigido.
- **Lint do `boleto-migrations` (corrigido antes do PR):** o Squawk recusou a V3 por `constraint-missing-not-valid`. O arquivo passou a ter `squawk-ignore-file` com o motivo (ADR 0056). O plano previa o `NOT VALID` seguido de `VALIDATE`.
- **Teste do `boleto-migrations`:** a primeira execução de `compose.test.yml` foi interrompida por conflito com outro Compose em paralelo. Repetida, passou.
- **CI:** nenhuma falha nos PRs #19 do `boleto-docs` e #7 do `boleto-migrations`.
- **Aviso do editor sobre o JAR do wrapper:** o editor avisou que o `gradle-wrapper.jar` do backend "could be malicious". O sha256 dele confere com o checksum oficial do Gradle 9.9.2, e a CI já validava o JAR com `gradle/actions/wrapper-validation` (fixada por SHA, v6.4.1) antes de qualquer `./gradlew`. Não era decisão nova: virou nota de consequência no [ADR 0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md) e a ordem passou ao README do backend.

## Decisões e desvios do plano

- Os ADRs 0051 a 0056 seguem o plano. A V3 saiu com `squawk-ignore-file` para duas regras (`require-concurrent-index-creation` e `constraint-missing-not-valid`), em vez do `NOT VALID` seguido de `VALIDATE` do plano ([ADR 0056](../adr/0056-v3-cpf-do-usuario.md)).
- O plano deixava o Compose para o PR B, depois do backend. Ele entrou junto com a documentação, porque o backend não sobe sem as chaves de CPF e os guias citam o Mailpit como dependência.
- **Fuso:** o usuário respondeu que o fuso deve ser o do local de onde a pessoa se loga, mas que por ora a plataforma atua só no Brasil. Fica `America/Sao_Paulo`, como no [ADR 0045](../adr/0045-claims-tempos-e-sessao-diaria.md) (só nota, sem mudar a decisão).
- Premissas do plano que o usuário ainda pode querer mudar: convite de 72 horas, recuperação de 30 minutos, CPF opcional, sem página provisória no backend, revogação de todas as sessões ao redefinir e chaves de dev públicas.

## Pendências

- Pull request do `boleto-backend`, com todos os workflows verdes e listados aqui.
- Demonstração do plano e o resumo dela neste registro.
- PR da documentação, com `CI` e `Documentação` verdes, e o Task 10 marcado `[x]` no `tasks.md` só depois disso.
- **Fuso do usuário logado** (vem do Task 9): evoluir a sessão diária para o fuso de quem se loga. Falta decidir de onde o fuso vem (usuário, empresa ou navegador) e como a meia-noite se comporta ao mudar de fuso. Pede novo ADR quando houver operação fora do Brasil.
- Limpeza e retenção de `token_usuario` (Task 15, [Inventário LGPD](../arquitetura/inventario-lgpd.md)).
- Métrica de falha de envio de e-mail (Task 11).
- Telas `/definir-senha` e `/redefinir-senha` (Task 13).
- Rotina de recifrar o CPF e runbook de rotação de chaves (Task 15, [Chaves de CPF](../guias/chaves-de-cpf.md)).

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-24 | Tag `v0.6.0` (PR #19) e V3 no `boleto-migrations` (PR #7) integradas |
| 2026-11-24 | Backend em branch (207 testes, 0 falhas). ADRs 0051 a 0056, inventário LGPD, guias, Compose e este registro, em andamento |
