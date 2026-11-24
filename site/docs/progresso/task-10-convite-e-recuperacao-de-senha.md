---
sidebar_position: 10
title: 'Task 10: Convite e "esqueci minha senha"'
---

# Task 10: Convite de usuário e "esqueci minha senha"

- **Situação:** Concluída
- **Início:** 2026-11-24
- **Última atualização:** 2026-11-24
- **Repositórios:** `boleto-docs`, `boleto-migrations` (V3), `boleto-backend`

## Objetivo

O administrador convida um usuário por e-mail, a pessoa define a senha pelo link, e quem esqueceu a senha recupera o acesso por e-mail. Entram junto o CPF cifrado do usuário, a máscara de dados pessoais nos logs e o envio de e-mail por SMTP. Demonstração: convite, e-mail no Mailpit, senha definida e login.

## Entregue

| Repositório | PR | Integração | Conteúdo |
|---|---|---|---|
| `boleto-docs` | [#19](https://github.com/Titulize/boleto-docs/pull/19) | squash `7a74113`, tag `v0.6.0` | o alvo `backend` da sincronização passou a entregar `MAILPIT_IMAGE`. Nenhuma biblioteca Java nova entrou no `versions.toml` |
| `boleto-migrations` | [#7](https://github.com/Titulize/boleto-migrations/pull/7) | squash `ba99f16` | V3 `V3__cpf_do_usuario.sql` e o teste `tests/sql/08e_cpf_usuario.sql` |
| `boleto-backend` | [#9](https://github.com/Titulize/boleto-backend/pull/9) | squash `863edfb` | `POST /usuarios`, `POST /usuarios/{id}/convite`, `POST /auth/definir-senha` e `POST /auth/esqueci-senha`, `shared.pii`, `shared.email`, `shared.log.MascaraDeDados`, `PoliticaDeSenha`, `TokenUsuarioServico` e o ouvinte de e-mail em `auth`. Commits do PR: `2be8e0d` (CI: imagem de migração com a V3, `MAILPIT_IMAGE` no cache, validação do wrapper no README) e `c744e3e` (código, testes e README) |
| `boleto-docs` | este PR (`docs/task-10-convite-senha`) | squash só depois de todos os workflows verdes (número do PR e do squash na página do PR) | ADRs, páginas, Compose e este registro |

No `boleto-docs` (este PR):

- ADRs [0051](../adr/0051-tokens-de-convite-e-recuperacao-de-senha.md) (tokens e fluxos), [0052](../adr/0052-politica-de-senha.md) (política de senha), [0053](../adr/0053-email-smtp-link-e-modelos.md) (e-mail, link e modelos), [0054](../adr/0054-cpf-criptografado-e-blind-index.md) (CPF cifrado), [0055](../adr/0055-mascara-de-dados-pessoais-nos-logs.md) (máscara nos logs) e [0056](../adr/0056-v3-cpf-do-usuario.md) (V3), com o índice atualizado.
- Notas de consequência, sem mudar decisão, nos ADRs [0012](../adr/0012-autenticacao.md), [0015](../adr/0015-lgpd.md), [0025](../adr/0025-modelo-de-dados-v1.md) ("CPF na V2" passou a V3), [0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md) (validação do wrapper) e [0045](../adr/0045-claims-tempos-e-sessao-diaria.md) (fuso confirmado).
- Páginas novas: [Inventário LGPD](../arquitetura/inventario-lgpd.md), [Convite e senha](../guias/convite-e-senha.md) e [Chaves de CPF](../guias/chaves-de-cpf.md).
- Páginas ajustadas: [Autenticação e autorização](../arquitetura/autenticacao.md), [Modelo de dados](../arquitetura/modelo-de-dados.md), [Erros da API](../arquitetura/erros-da-api.md) (`TOKEN_SENHA_INVALIDO` e `SENHA_FRACA`), [Módulos do backend](../arquitetura/modulos-backend.md), [Containers](../arquitetura/containers.md), [Migrações do banco](../guias/migracoes.md) e [Compose de desenvolvimento](../guias/compose-dev.md).
- `docker-compose.yml`: o `backend` espera o `mailpit` saudável e recebe `SPRING_MAIL_*`, `BOLETO_APP_URL_BASE`, `BOLETO_EMAIL_REMETENTE` e as chaves de CPF de desenvolvimento (constantes públicas `DEV-ONLY-`, sem a chave efêmera). `.env.example` e `scripts/compose.test.mjs` acompanham, e o teste recusa qualquer chave de CPF do Compose que não seja a constante de dev.

## Verificação

### Testes

| Onde | Resultado |
|---|---|
| `boleto-backend`, em `c744e3e` (`.\gradlew.bat spotlessCheck check --rerun-tasks`, com `MIGRATIONS_CONTEXT` na `main` do `boleto-migrations`, V3) | 207 testes em 44 classes, 0 falhas, 0 erros, 0 ignorados. Jacoco 92,3% das linhas (mínimo 80%) |
| `boleto-docs` (`npm test`) | 44 testes, 0 falhas |
| `boleto-migrations` | lint Squawk e testes de isolamento por tenant no PostgreSQL real, pela CI (PR e `main`) |

### Verificação local

| O quê | Como | Resultado |
|---|---|---|
| Imagem do backend | `docker build -t boleto-backend:dev .`; usuário `uid=10001 gid=10001` | passou |
| Workflows do backend | `actionlint` (`rhysd/actionlint`) | sem erros |
| Versões do `boleto-docs` | `npm run validate`, `npm run sync:check`, `npm test` | passaram |
| Compose | `docker compose config -q` | passou |
| Site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | passou, sem links quebrados (repetido antes do envio deste PR) |
| Commits | `npx commitlint --from origin/main --to HEAD` | passou |

### CI

| Repositório | Run | Evento | Resultado |
|---|---|---|---|
| `boleto-docs` (#19) | CI e `Documentação` do PR e da `main` | `pull_request` e `push` | todos `success` (Bootstrap Linux, Bootstrap Windows PowerShell 5.1, Build do site, Compose de desenvolvimento, Conventional Commits, Validar `versions.toml` e testes; `Publicar no GitHub Pages` ignorado no PR) |
| `boleto-migrations` (#7) | [45322947449](https://github.com/Titulize/boleto-migrations/actions/runs/45322947449) | `pull_request` | `success`: Conventional Commits (18 s) e Lint, imagem e testes de isolamento (2 min 4 s) |
| `boleto-migrations` | [45323226848](https://github.com/Titulize/boleto-migrations/actions/runs/45323226848) | `push` na `main` (`ba99f16`) | `success` (2 min 10 s) |
| `boleto-backend` (#9) | [45334295800](https://github.com/Titulize/boleto-backend/actions/runs/45334295800) | `pull_request` | `success`: Conventional Commits (17 s) e Build, testes, Spotless, Jacoco e imagem (5 min 38 s) |
| `boleto-backend` | [45335075591](https://github.com/Titulize/boleto-backend/actions/runs/45335075591) | `push` na `main` (`863edfb`) | `success` no build e testes; Conventional Commits `skipped` (só roda em PR) |
| `boleto-docs` (este PR) | CI e `Documentação` | `pull_request` e `push` na `main` | só integrado com todos os workflows verdes; os links ficam no PR do `boleto-docs` |

Nos dois runs do backend o step `Validar o JAR do Gradle Wrapper` terminou com `success` antes do step do Gradle. O `boleto-migrations` e o `boleto-backend` não têm outros workflows.

### Demonstração

Executada em 2026-11-24 em contêineres reais (PostgreSQL 18.7, Valkey, Mailpit 1.34.0, migração V3 da `main` do `boleto-migrations` em `ba99f16`, backend do commit `c744e3e`), num projeto Compose isolado (`boleto-task10-demo`, portas 15432, 16379, 11025, 18025 e 18080), sem tocar no ambiente `boleto-dev`. Resultado: todos os passos do roteiro passaram, sem defeito no backend.

| Passo | Resultado |
|---|---|
| Login do admin | 200 |
| `POST /usuarios` (CPF de teste, perfil Administrador da plataforma) | 201, `situacao: CONVIDADO`, `cpfMascarado: ***.982.247-**`, sem CPF em claro |
| E-mail no Mailpit | 1 e-mail ao convidado, link `http://localhost:4200/definir-senha#token=<oculto>` (token de 43 caracteres), texto "72 horas" |
| `POST /auth/definir-senha` | 204. Repetir o mesmo token: 400 `TOKEN_SENHA_INVALIDO` |
| Login do usuário novo | 200 |
| `POST /auth/esqueci-senha` (e-mail existente e inexistente) | dois 202 com cabeçalhos e corpo iguais, exceto `X-Trace-Id` e `Date`. Só o existente recebeu e-mail |
| Redefinição pelo link | 204. Refresh anterior: 401 `TOKEN_INVALIDO`. Login com a senha antiga: 401. Com a nova: 200 |
| Banco, `usuario` | `cpf_cifrado` 39 bytes, `cpf_indice` 32 bytes, `cpf_chave_versao` 1. Os 11 dígitos não aparecem nos bytes |
| Banco, `token_usuario` | `CONVITE` e `RECUPERACAO_SENHA`, `token_hash` de 32 bytes, `usado_em` preenchido nos dois |
| Banco, `usuario_aud` | nenhuma coluna `cpf%` |
| Logs do backend, `/v3/api-docs` e corpo dos e-mails | 0 ocorrências de e-mail completo, nome completo, CPF (com e sem pontuação), tokens e senhas. Os logs trazem só o id do usuário e o e-mail mascarado (`m***@example.com`) |
| Limite de pedidos | log "Recuperação de senha acima do limite" com e-mail mascarado |
| Subida | aviso "Chaves de dados pessoais de DESENVOLVIMENTO em uso", como previsto |

**Não verificado:** envio por SES real; link abrindo página do frontend (rotas do Task 13); rotação de chave de CPF com dados reais; limpeza de tokens expirados; expiração por tempo (72 h e 30 min), coberta só pelos testes automatizados; revogação de sessão com o Valkey fora do ar.

## Falhas e correções

- **Interrupção do run anterior por limite de uso:** o run do fluxo de trabalho parou no passo `backend-code` com a mensagem "Usage limit reached". Não foi falha de código nem de teste. O passo foi retomado e concluído depois, e o commit `c744e3e` saiu com os 207 testes passando.
- **Teste do backend (corrigido antes do commit):** `DefinirSenhaIT` exigia que a mensagem de senha fraca não citasse o exemplo `123456789012`, que a própria regra de sequência cita. O teste foi corrigido.
- **Lint do `boleto-migrations` (corrigido antes do PR):** o Squawk recusou a V3 por `constraint-missing-not-valid`. O arquivo passou a ter `squawk-ignore-file` com o motivo ([ADR 0056](../adr/0056-v3-cpf-do-usuario.md)).
- **Teste do `boleto-migrations`:** a primeira execução de `compose.test.yml` foi interrompida por conflito com outro Compose em paralelo. Repetida, passou.
- **Verificação local do backend:** na primeira execução do Gradle no worktree, `:construirImagemMigracoes` falhou com "Sem Dockerfile em ...\boleto-backend\.worktrees\boleto-migrations", porque o worktree fica em `.worktrees/` e o `boleto-migrations` não está ao lado. Resolvido definindo `MIGRATIONS_CONTEXT`, como o README orienta. A primeira gravação do log do Gradle por redirecionamento do PowerShell falhou ("arquivo já está sendo usado por outro processo") e foi repetida por `cmd /c`.
- **Demonstração (falhas do roteiro, não do backend):** as primeiras execuções do `demo.ps1` falharam por erros do script (`curl` devolvendo array em vez de texto, filtro que escondia o corpo e variável `$M` colidindo com `$m`). Execuções antigas, deixadas em segundo plano, gastaram o limite por IP (429 `LIMITE_EXCEDIDO` em `/auth/**`) e o de 3 pedidos por e-mail, e criaram o usuário de teste duas vezes. O script foi corrigido e a demonstração repetida do zero (`down -v`, `up`).
- **Aviso do editor sobre o JAR do wrapper:** o editor avisou que o `gradle-wrapper.jar` do backend "could be malicious". O sha256 dele confere com o "Wrapper JAR" do Gradle 9.9.2 em [gradle.org/release-checksums](https://gradle.org/release-checksums/) (conferido em 2026-11-24), e a CI já validava o JAR com `gradle/actions/wrapper-validation` (fixada por SHA, v6.4.1) antes de qualquer `./gradlew`. Virou nota no [ADR 0033](../adr/0033-wrapper-qualidade-e-ci-do-backend.md), e a ordem passou ao README do backend.
- **Achados da revisão da documentação (corrigidos neste PR):** o registro não trazia o resultado do build do site e do commitlint, o `erros-da-api.md` descrevia a regra de contexto da senha como "início do e-mail" (o código e o ADR 0052 usam a parte local do e-mail), o ADR 0033 não citava a fonte do checksum e o `compose-dev.md` citava só a V2.
- **CI:** nenhuma falha nos PRs #19 e #9 e #7, nem nas `main` depois do merge.

## Decisões e desvios do plano

- Os ADRs 0051 a 0056 seguem o plano. A V3 saiu com `squawk-ignore-file` para duas regras (`require-concurrent-index-creation` e `constraint-missing-not-valid`), em vez do `NOT VALID` seguido de `VALIDATE` do plano ([ADR 0056](../adr/0056-v3-cpf-do-usuario.md)).
- O plano deixava o Compose para o PR B, depois do backend. Ele entrou junto com a documentação, porque o backend não sobe sem as chaves de CPF e os guias citam o Mailpit como dependência.
- **Fuso:** o usuário respondeu que o fuso deve ser o do local de onde a pessoa se loga, mas que por ora a plataforma atua só no Brasil. Fica `America/Sao_Paulo`, como no [ADR 0045](../adr/0045-claims-tempos-e-sessao-diaria.md) (só nota, sem mudar a decisão).
- Premissas do plano que o usuário ainda pode querer mudar: convite de 72 horas, recuperação de 30 minutos, CPF opcional, sem página provisória no backend, revogação de todas as sessões ao redefinir e chaves de dev públicas.

## Pendências

Nenhuma para fechar o Task 10. Itens deixados para outras tarefas:

- **Fuso do usuário logado** (vem do Task 9): evoluir a sessão diária para o fuso de quem se loga. Falta decidir de onde o fuso vem (usuário, empresa ou navegador) e como a meia-noite se comporta ao mudar de fuso. Pede novo ADR quando houver operação fora do Brasil.
- Limpeza e retenção de `token_usuario` (Task 15, [Inventário LGPD](../arquitetura/inventario-lgpd.md)).
- Métrica de falha de envio de e-mail (Task 11).
- Telas `/definir-senha` e `/redefinir-senha` (Task 13).
- Rotina de recifrar o CPF e runbook de rotação de chaves (Task 15, [Chaves de CPF](../guias/chaves-de-cpf.md)).
- Mensagem de erro em inglês ("Failed to read request") no `detail` do 400 `REQUISICAO_INVALIDA` para JSON malformado. Comportamento do tratador de erros anterior ao Task 10, fora do escopo. O padrão pede texto de interface em português, então vale uma tarefa própria.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-24 | Tag `v0.6.0` (PR #19) e V3 no `boleto-migrations` (PR #7) integradas |
| 2026-11-24 | Backend em branch (207 testes, 0 falhas). ADRs 0051 a 0056, inventário LGPD, guias, Compose e este registro, em andamento |
| 2026-11-24 | Backend integrado (PR #9, squash `863edfb`, CI verde no PR e na `main`). Demonstração executada. Registro concluído |
