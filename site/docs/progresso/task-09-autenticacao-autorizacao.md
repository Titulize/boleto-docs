---
sidebar_position: 9
title: 'Task 09: Autenticação e autorização'
---

# Task 09: Autenticação e autorização

- **Situação:** Em andamento (implementação local pronta; falta enviar os PRs e a CI)
- **Início:** 2026-11-23
- **Última atualização:** 2026-11-23
- **Repositórios:** `boleto-docs`, `boleto-backend` (o `boleto-migrations` não muda)

## Objetivo

O backend passa a autenticar com JWT e refresh rotativo no Valkey, encerrar a sessão no logout e na meia-noite, limitar tentativas (Bucket4j e bloqueio de conta), autorizar cada rota por tela e ação, deixar a plataforma assumir uma empresa e criar o administrador inicial. Demonstração: login no Swagger e 429 acima do limite.

## Entregue

Tudo em commits locais na branch `feat/task-09-autenticacao` dos dois repositórios, ainda sem push.

`boleto-docs`:

- `54e7f6d`: o `backend` do `docker-compose.yml` depende do `valkey` (`service_healthy`) e recebe `SPRING_DATA_REDIS_*`, `BOLETO_JWT_GERAR_CHAVE_EFEMERA=true` e `BOLETO_ADMIN_INICIAL_*` com padrões de dev; `.env.example` e `scripts/compose.test.mjs` acompanham.
- `64c30b1`: ADRs [0044](../adr/0044-jwt-es256-e-chave.md) a [0050](../adr/0050-contexto-de-tenant-jwt-e-threads.md), notas de consequência nos ADRs 0012 e 0013, a página [Autenticação e autorização](../arquitetura/autenticacao.md) e ajustes em `erros-da-api`, `modulos-backend`, `multitenancy-e-auditoria`, `modelo-de-dados`, `containers`, `compose-dev` e `ambiente-do-dev`.
- `6632d67`: redação do ADR 0012 e tabela de chaves do ADR 0046 corrigidas.
- Fechamento (este registro): linha no [índice](./index.md), README, `autenticacao.md` e ADR 0046 alinhados com o que foi implementado (formato de `refresh:{hash}`, TTL de `sessao-revogada` no logout), `multitenancy-e-auditoria.md` com a auditoria de perfis, o executor com contexto e a correção do Envers.

`boleto-backend`:

- `a22b263` `feat(auth)`: dependências (starters de security, oauth2-resource-server e data-redis do BOM do Spring Boot 4.1.3; Bucket4j 8.22.0 e Bouncy Castle 1.87 do `libs.versions.toml`), `SegurancaConfig`, JWT ES256 (`ChaveJwt`, `JwtConfig`, `EmissorDeTokens`, `DecodificadorJwt`), `SessaoRepositorio` com o script Lua de rotação, `LoginServico`, `RefreshServico`, `LogoutServico`, `AssumirEmpresaServico`, `LimitadorDeRequisicoes` e `FiltroLimiteIp`, `IpDoCliente`, `ContextoTenantFilter`, `Autorizacao`, `AuthController`, `AdminInicial`, `MascaraDeEmail`, `OpenApiConfig` (`bearerAuth`); entidades `Perfil`, `PerfilTelaPermissao` e `UsuarioPerfil` (`@Audited`), `PerfilServico`; `shared.seguranca` (`@RequerPermissao`, `Acao`, `Telas`), `ContextoTaskDecorator` e `executorComContexto`; 7 códigos novos no `CodigoErro`; `ci.yml` com `VALKEY_IMAGE` no cache (chave `imagens-backend-v2`).
- `d044b89` `test(auth)`: Valkey no `TestcontainersConfiguration`, `RelogioControlado`, `SegurancaDeTesteConfig` e os testes de login, senha, sessão diária, JWT, refresh, logout, bloqueio, limite por IP, IP do cliente, Valkey fora do ar, tenant do JWT, admin inicial, logs e demonstração (`DemoSwaggerIT`).
- `b7361fe` `test(auth)`: `PermissaoIT`, `PerfilServicoIT`, `AssumirEmpresaIT`, `AuditoriaPerfilIT`, `ContextoTaskDecoratorTest`, `SemCabecalhoDeTenantTest` e três regras novas no `ArquiteturaTest` (`@RequerPermissao` em toda rota fora do `auth`, nenhuma leitura de cabeçalho fora do `auth`, `@Async` só com `executorComContexto`); correção das chaves do Envers no `application.yml`; README.
- `6dcf1d4` `fix(auth)`: `gerar-chave-efemera` passa a ler `BOLETO_JWT_GERAR_CHAVE_EFEMERA` (sem isso o backend não subia no Compose); README com o jeito de repetir a demonstração.
- `caadd34` `fix(auth)`: o token de empresa assumida (`tid` diferente de `tor`) reconfere `PLATAFORMA_EMPRESAS:VISUALIZAR` a cada requisição; `AssumirEmpresaIT` ganhou o caso.

`boleto-migrations`: **sem V3.** O bloqueio por tentativas fica no Valkey; `usuario.senha_hash`, as tabelas `perfil_aud`, `perfil_tela_permissao_aud` e `usuario_perfil_aud` e os grants já existem na V1.

**Sem tag nova do `boleto-docs`:** Bucket4j, Bouncy Castle e `VALKEY_IMAGE` já estavam no `versions.toml` v0.5.0; Spring Security, Nimbus JOSE e Spring Data Redis vêm do BOM do Spring Boot.

## Verificação

Execução local no Windows, Docker Desktop, `MIGRATIONS_CONTEXT` apontando para o `boleto-migrations` em `e332e02`.

| O quê | Como | Resultado |
|---|---|---|
| Baseline do backend antes de mexer | `.\gradlew.bat spotlessCheck check` | passou |
| Suíte do backend | `.\gradlew.bat spotlessApply spotlessCheck check` em `b7361fe` e `spotlessCheck check` em `6dcf1d4` | 106 testes, 0 falhas; Jacoco 847 de 908 linhas (93%); mínimo 80% (medido em `6dcf1d4`) |
| Suíte do backend depois da correção da revisão | `spotlessCheck check` em `caadd34` | 107 testes, 0 falhas, 0 ignorados; Jacoco 854 de 915 linhas (93%) |
| Imagem do backend | `docker build -t boleto-backend:t09 .` | passou |
| Versões do backend | `node .platform/sync-versions.mjs check --remote` | versões em dia |
| Commits | `npx commitlint --from origin/main --to HEAD` nos dois repositórios | passou (um aviso `footer-leading-blank` no `6dcf1d4`, sem erro) |
| Compose | `docker compose config -q` | passou |
| Scripts do `boleto-docs` | `npm run validate`, `npm run sync:check`, `npm test` | passaram |
| Site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | passou, sem links quebrados |

### Demonstração

Executada em 2026-11-23 com `docker compose up -d --build --wait` no worktree do `boleto-docs`, `BACKEND_CONTEXT` no worktree do backend (`6dcf1d4`) e `MIGRATIONS_CONTEXT` no `boleto-migrations`. As chamadas HTTP são as mesmas do "Try it out" do Swagger:

```
swagger-ui.html: 302 -> /swagger-ui/index.html
api-docs: 200, bearerAuth presente: True
login admin: 200
tipo=Bearer expiraEm=2026-11-23T05:48:34Z sessaoExpiraEm=2026-11-24T03:00:00Z
me: 200 tenantId=00000000-0000-7000-8000-000000000001 origem=00000000-0000-7000-8000-000000000001 permissoes=16
me sem token: 401 NAO_AUTENTICADO
tentativa errada 1 a 5: 401 CREDENCIAIS_INVALIDAS
tentativa errada 6: 429 LIMITE_EXCEDIDO Retry-After=889
logout: 204
me depois do logout: 401 TOKEN_INVALIDO
```

`sessaoExpiraEm` 03:00 UTC é a meia-noite de `America/Sao_Paulo`. O administrador `admin@boleto.test` foi criado pelo `AdminInicial` com o perfil da plataforma (16 permissões).

### Workflows

Nenhum ainda: não houve push. Ao enviar, acompanhar:

| Repositório | Workflow | Eventos |
|---|---|---|
| `boleto-backend` | `CI` (`Conventional Commits` e `Build, testes, Spotless, Jacoco e imagem`) | PR e `main` depois do squash |
| `boleto-docs` | `CI` e `Documentação` | PR e `main` depois do squash |

### O que não foi verificado

- **CI remota** dos dois repositórios, inclusive o `ci.yml` do backend com `VALKEY_IMAGE` e a chave de cache `imagens-backend-v2`. O `actionlint` não foi rodado.
- **Swagger UI no navegador.** A demonstração usou as mesmas chamadas HTTP; o clique em "Authorize" e o "Try it out" não foram feitos numa tela.
- **Chave real em `BOLETO_JWT_CHAVE_PRIVADA`.** Só o `JwtValidacaoTest` exercita a derivação da chave pública; o Compose usa a chave efêmera.
- `X-Forwarded-For` atrás de um proxy real, concorrência com várias instâncias do backend, Argon2 sob carga.
- O TTL do Valkey corre no relógio real: os testes com `RelogioControlado` não aceleram a expiração de `login-falhas` nem dos baldes.
- A regra `rotaForaDoAuthExigePermissao` do ArchUnit roda vazia: ainda não existe rota fora do `auth` no código de produção (a rota de teste `/protegido/leitura` fica em `src/test`).

## Falhas e correções

- **`UsuarioRepository.findByEmail` derivado quebrava a subida** (o Hibernate valida a query sem tenant e o `TenantIdResolver` estrito recusa). Virou consulta JPQL montada na hora no `UsuarioServico`. Repositórios de entidades com `@TenantId` não devem ter métodos derivados nem `@Query`.
- **O verificador de claims padrão do `NimbusJwtDecoder`** usava o relógio real com 60 s de folga e o `SessaoDiariaTest` falhou. Passou a ser no-op, e os validadores com o `Clock` e folga zero conferem as datas.
- **`InternalAuthenticationServiceException` escapava** no caso do Valkey fora do ar. O `DecodificadorJwt` passou a lançar uma `AuthenticationException` própria, e o entry point acha o 503 na cadeia de causas.
- **`npm test` do `boleto-docs` falhou** porque o `compose.test.mjs` afirmava que o backend não depende do Valkey. O teste passou a exigir a dependência e as variáveis novas.
- **Commit do `boleto-docs` recusado pelo hook** (`subject-case`) e uma edição que duplicou seções de `erros-da-api.md`. Título reescrito e duplicação removida antes do commit.
- **`AuditoriaPerfilIT` falhou na exclusão de `usuario_perfil`:** a revisão `DEL` gravava `tenant_id` nulo e a RLS da `usuario_perfil_aud` recusava. Causa: as chaves `org.hibernate.envers.*` do `application.yml` estavam aninhadas em `hibernate` desde o Task 8 e não chegavam ao Envers (valiam os padrões, que coincidem com o schema). As chaves foram movidas e ganharam `store_data_at_delete: true`. A exclusão de `Usuario` e `EmpresaGestora` teria o mesmo problema.
- **`AssumirEmpresaIT`** esperava `refreshToken: null` no JSON, mas o campo é omitido (`@JsonInclude(NON_NULL)`). O teste passou a conferir a ausência.
- **Execuções do Gradle sobrepostas** (a ferramenta devolveu o controle antes do fim e uma segunda execução começou) deram `BindException` ao conectar no PostgreSQL do Testcontainers em um teste. A execução seguinte, sozinha, passou.
- **O backend não subiu no `docker compose up`:** `BOLETO_JWT_GERAR_CHAVE_EFEMERA` não chegava ao Spring, porque o `application.yml` fixava `false` e o nome da variável não segue a ligação relaxada de `boleto.seguranca.jwt.gerar-chave-efemera`. Corrigido no `6dcf1d4` com `${BOLETO_JWT_GERAR_CHAVE_EFEMERA:false}`.
- **Token de empresa assumida sobrevivia à perda do perfil de plataforma** até o `exp` (achado da revisão): o filtro só conferia a permissão na emissão. Corrigido em `caadd34`: a cada requisição com `tid` diferente de `tor`, o backend reconfere `PLATAFORMA_EMPRESAS:VISUALIZAR` e devolve 401 se faltar.
- **ADR 0046 contradizia a si mesmo e o ADR 0012 tinha um caractere ESC** (achados da revisão): a tabela de chaves divergia da seção Consequências e o ESC estava no texto. Corrigidos em `6632d67`.
- **Primeira rodada da demonstração com 429 na 3ª tentativa:** uma rodada anterior, no mesmo minuto, já tinha gasto o limite de 10 logins por minuto do e-mail. Com o Valkey de dev limpo (`FLUSHALL`), a rodada deu 401 cinco vezes e 429 na sexta. O README do backend e a página de autenticação explicam como repetir.

## Decisões e desvios do plano

- ADRs [0044](../adr/0044-jwt-es256-e-chave.md) a [0050](../adr/0050-contexto-de-tenant-jwt-e-threads.md), como no plano; o 0012 e o 0013 ganharam só notas de consequência.
- `refresh:{hash}` guarda `sid|usuarioId|tenantOrigem|sessaoExpiraEm` (o plano dizia `sid|usuarioId`); o script Lua também confere a revogação e o fim da sessão e, no reuso, já revoga a sessão. TTL de `sessao-revogada` no logout fixo em 25 horas. Registrado nas consequências do [ADR 0046](../adr/0046-refresh-e-blacklist-no-valkey.md).
- Um usuário que deixa de ser `ATIVO` perde o acesso na hora: a situação é conferida a cada requisição (401 `TOKEN_INVALIDO`).
- `ErroNegocio` ganhou o campo opcional de espera, que vira `Retry-After`.
- `SemCabecalhoDeTenantTest` (busca do texto `X-Tenant-Id` em `src/main/java`) complementa a regra do ArchUnit, que não enxerga literais.

## Pendências

- **Enviar e integrar:** push das branches, PRs no `boleto-backend` e no `boleto-docs`, acompanhar todos os workflows e registrar os runs aqui. O Task 9 só fica concluído depois disso.
- **Frontend (Tasks 12 e 13):** ao carregar ou recarregar a página, o Angular chama `POST /auth/refresh` para obter um novo access. Isso exige guardar o refresh entre recarregamentos (sessionStorage ou cookie HttpOnly), escolha do frontend que reabre a evolução para cookie ([ADR 0046](../adr/0046-refresh-e-blacklist-no-valkey.md)).
- **Fuso da sessão diária:** `America/Sao_Paulo` é suposição a confirmar com o usuário ([ADR 0045](../adr/0045-claims-tempos-e-sessao-diaria.md)).
- **Teste de `store_data_at_delete` nas exclusões de `Usuario` e `EmpresaGestora`:** só a exclusão de `usuario_perfil` tem teste (`AuditoriaPerfilIT`). As outras duas dependem da mesma configuração do Envers, mas não têm teste. Pendência de segurança (a RLS recusaria a revisão `DEL` com `tenant_id` nulo).
- **Produção:** preencher `BOLETO_JWT_CHAVE_PRIVADA` pelo Secrets Manager (fora do escopo da Fase 1).
- Convite e "esqueci minha senha" ficam no Task 10.

Pendências do Task 8 resolvidas aqui: o `ContextoTenant` é ligado pelo JWT validado; o contexto é propagado no executor `executorComContexto`; o `X-Tenant-Id` é ignorado em controller real (`TenantDoJwtIT` com `/auth/me`); `perfil*` e `usuario_perfil` são auditados; a exclusão (`DEL`) ganhou teste (`AuditoriaPerfilIT`). Seguem abertos os testes de `REQUIRES_NEW`, `readOnly` e concorrência com `@Version`.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-23 | ADRs 0044 a 0050, Compose e páginas de arquitetura no `boleto-docs` |
| 2026-11-23 | Autenticação, sessão, refresh, limites e testes no `boleto-backend` |
| 2026-11-23 | Correções da revisão: permissão reconferida no token de empresa assumida (`caadd34`), ADRs 0012 e 0046 (`6632d67`) e este registro |
| 2026-11-23 | Autorização, assumir empresa, auditoria de perfis, regras ArchUnit, demonstração no Compose e este registro; falta o envio |
