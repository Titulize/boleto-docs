---
sidebar_position: 9
title: 'Task 09: Autenticação e autorização'
---

# Task 09: Autenticação e autorização

- **Situação:** Concluída
- **Início:** 2026-11-23
- **Última atualização:** 2026-11-24
- **Repositórios:** `boleto-docs`, `boleto-backend` (o `boleto-migrations` não muda)

## Objetivo

O backend passa a autenticar com JWT e refresh rotativo no Valkey, encerrar a sessão no logout e na meia-noite, limitar tentativas (Bucket4j e bloqueio de conta), autorizar cada rota por tela e ação, deixar a plataforma assumir uma empresa e criar o administrador inicial. Demonstração: login no Swagger e 429 acima do limite.

## Entregue

O backend entrou na `main` do `boleto-backend` pelo [PR #8](https://github.com/Titulize/boleto-backend/pull/8), por squash (`00da90ba6ac7eabcfd221e48dfb4593c8c3ed7f7`, título `feat(auth): autenticacao JWT, refresh, sessao diaria, bloqueio e permissoes (#8)`). A `main` não andou desde a base da branch (`ee105a3`), então não houve rebase. Os hashes abaixo são os dos commits da branch, que o squash reuniu. A documentação entra pelo PR do `boleto-docs` que contém este registro.

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
| Suíte do backend depois da correção da revisão (contagem final) | `spotlessCheck check` em `caadd34` e CI do PR #8 | 107 testes, 0 falhas, 0 ignorados; Jacoco: 94,2% das instruções (3767 de 3999), 82,6% dos branches (157 de 190), 93,3% das linhas (854 de 915); mínimo 80% |
| Imagem do backend | `docker build -t boleto-backend:t09 .` | passou |
| Versões do backend | `node .platform/sync-versions.mjs check --remote` | versões em dia |
| Commits | `npx commitlint --from origin/main --to HEAD` nos dois repositórios | passou (um aviso `footer-leading-blank` no `6dcf1d4`, sem erro) |
| CI remota do `boleto-backend` | PR #8 e `main` depois do squash | passou (ver "Workflows") |
| `actionlint` no `ci.yml` do backend | antes do push | sem erros |
| Compose | `docker compose config -q` | passou |
| Scripts do `boleto-docs` | `npm run validate`, `npm run sync:check`, `npm test` | passaram |
| Site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | passou, sem links quebrados |

### Demonstração

Executada em 2026-11-23 (23h30 em `America/Sao_Paulo`) num projeto Compose separado (`boleto-demo-task09`, portas 25432, 26379, 21025, 28025 e 28080), com `BACKEND_CONTEXT` no worktree do backend em `caadd34`, `MIGRATIONS_CONTEXT` no `boleto-migrations` (sem V3) e um arquivo de override só com os nomes das imagens. Ele evita que o build sobrescreva `boleto-backend:dev` e `boleto-migrations:dev` do `boleto-dev`. Postgres, Valkey e Mailpit saudáveis, `flyway` com código 0 e backend saudável em cerca de 10 s. As chamadas HTTP são as mesmas do "Try it out" do Swagger. Sem tokens nem senhas reais abaixo:

```
swagger-ui: 200 em /swagger-ui/index.html; /v3/api-docs declara bearerAuth
login (admin de dev): 200, accessToken e refreshToken, sessaoExpiraEm informado
GET /auth/me: 200, 16 permissões, tenant efetivo e tenant de origem; sem token: 401 NAO_AUTENTICADO
refresh com rotação: 200, refresh novo diferente, sessaoExpiraEm igual
reuso do refresh antigo: 401 REFRESH_REUTILIZADO; refresh novo e access da sessão passam a dar 401
logout: 204; access e refresh depois dele dão 401
seis logins errados: 401 CREDENCIAIS_INVALIDAS x5; 6ª: 429 LIMITE_EXCEDIDO, Retry-After 899
login correto durante o bloqueio: 429
usuário sem perfil em POST /auth/assumir-empresa: 403 SEM_PERMISSAO
admin da plataforma assume empresa: 200, novo access sem refresh (tid da empresa, tor da plataforma, mesmo sid e exp); empresa inexistente: 404
exp limitado pela meia-noite, ao vivo: login às 23h31 gerou exp às 00h00 (28 min, não 1 h)
SessaoDiariaTest (5) e DemoSwaggerIT (1) com relógio controlado: 6 testes, 0 falhas
```

O administrador inicial foi criado pelo `AdminInicial` (log com e-mail mascarado). Para o 403 e o assumir empresa, uma empresa extra e um usuário sem perfil foram inseridos por SQL no banco da demonstração. Ao fim, `down -v` e remoção das duas imagens `*-demo`; os volumes `boleto-dev_*` ficaram intactos.

Uma primeira rodada, no Compose do worktree do `boleto-docs` (backend em `6dcf1d4`), tinha dado o mesmo resultado em login, `/auth/me`, 429 e logout.

### Workflows

| Repositório | Workflow | Run | Resultado |
|---|---|---|---|
| `boleto-backend` | `CI`, job "Build, testes, Spotless, Jacoco e imagem" (PR #8) | [45313697931](https://github.com/Titulize/boleto-backend/actions/runs/45313697931) | passou (5m16s) |
| `boleto-backend` | `CI`, job "Conventional Commits" (PR #8) | [45313697931](https://github.com/Titulize/boleto-backend/actions/runs/45313697931) | passou (20s) |
| `boleto-backend` | `CI` na `main` (`00da90b`) | [45314400899](https://github.com/Titulize/boleto-backend/actions/runs/45314400899) | passou |

O `boleto-backend` só tem o workflow `CI`. Os workflows `CI` e `Documentação` do `boleto-docs` (PR e `main`) são acompanhados no envio deste registro. O resultado deles consta no tasks.md e no relatório do envio, porque o registro vai junto com o PR e não pode citar o resultado dele.
### O que não foi verificado

- **Swagger UI no navegador.** A demonstração usou as mesmas chamadas HTTP; o clique em "Authorize" e o "Try it out" não foram feitos numa tela.
- **Ao vivo:** Valkey fora do ar (503), concorrência de refresh, 429 por IP e `X-Forwarded-For` só têm cobertura nos testes automatizados (que passaram na CI). A troca de perfil sem novo login e a auditoria de `perfil*` também só nos testes.
- **Logs completos da CI:** não foram lidos, porque nenhum job falhou.
- **`docker compose up` do `boleto-docs` depois do squash:** não repetido; a demonstração rodou antes, nos commits da branch.
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
- **Revisão (veredito final APROVADO):** a revisão apontou três itens, todos acima: token de empresa assumida (`caadd34`), contradição do ADR 0046 e caractere ESC no ADR 0012 (`6632d67`). Registrou ainda três riscos aceitos, sem mudança: o bloqueio por e-mail permite negar acesso a um usuário de propósito ([ADR 0047](../adr/0047-rate-limiting-e-bloqueio-de-conta.md)); dois refreshs simultâneos legítimos revogam a sessão ([ADR 0046](../adr/0046-refresh-e-blacklist-no-valkey.md), relevante ao frontend); a senha de dev do administrador fica no Compose público, por decisão do plano.
- **Falhas de CI:** nenhuma. Nem o PR #8 nem a `main` do backend tiveram job vermelho.
- **Falhas só dos comandos locais do envio do backend, sem efeito no código:** um script de cobertura do Jacoco procurou um CSV que não existe (a leitura foi refeita pelo XML) e a saída de um `docker build` veio vazia numa chamada (repetido gravando em arquivo, exit 0).
- **`up -d --build --wait` voltou com código 0 antes de backend e `flyway` estarem prontos** (ainda em `Created`), na demonstração. Não investigado; a espera foi feita por polling do healthcheck.
- **Nomes de imagem fixos no Compose** (`boleto-backend:dev`, `boleto-migrations:dev`): subir outro projeto sem trocá-los sobrescreve as imagens do `boleto-dev`. Evitado com um override de nomes e registrado no [guia do Compose](../guias/compose-dev.md).
- **Primeira rodada da demonstração com 429 na 3ª tentativa:** uma rodada anterior, no mesmo minuto, já tinha gasto o limite de 10 logins por minuto do e-mail. Com o Valkey de dev limpo (`FLUSHALL`), a rodada deu 401 cinco vezes e 429 na sexta. O README do backend e a página de autenticação explicam como repetir.

## Decisões e desvios do plano

- ADRs [0044](../adr/0044-jwt-es256-e-chave.md) a [0050](../adr/0050-contexto-de-tenant-jwt-e-threads.md), como no plano; o 0012 e o 0013 ganharam só notas de consequência.
- `refresh:{hash}` guarda `sid|usuarioId|tenantOrigem|sessaoExpiraEm` (o plano dizia `sid|usuarioId`); o script Lua também confere a revogação e o fim da sessão e, no reuso, já revoga a sessão. TTL de `sessao-revogada` no logout fixo em 25 horas. Registrado nas consequências do [ADR 0046](../adr/0046-refresh-e-blacklist-no-valkey.md).
- Um usuário que deixa de ser `ATIVO` perde o acesso na hora: a situação é conferida a cada requisição (401 `TOKEN_INVALIDO`).
- `ErroNegocio` ganhou o campo opcional de espera, que vira `Retry-After`.
- `SemCabecalhoDeTenantTest` (busca do texto `X-Tenant-Id` em `src/main/java`) complementa a regra do ArchUnit, que não enxerga literais.

## Pendências

Definição de pronto: código, testes e demonstração no repositório (feito); verificações locais e workflows do backend verdes (feito; os do `boleto-docs` constam no tasks.md); documentação e READMEs atualizados (feito); `tasks.md` com o estado real (feito). Nada do que o Task 9 prometia ficou aberto. Itens que seguem para depois, sem bloquear o fechamento:

- **Frontend (Tasks 12 e 13):** ao carregar ou recarregar a página, o Angular chama `POST /auth/refresh` para obter um novo access. Isso exige guardar o refresh entre recarregamentos (sessionStorage ou cookie HttpOnly), escolha do frontend que reabre a evolução para cookie ([ADR 0046](../adr/0046-refresh-e-blacklist-no-valkey.md)).
- **Fuso da sessão diária (confirmado em 2026-11-24, evolução pendente):** o usuário confirmou `America/Sao_Paulo`: por ora a plataforma atua só no Brasil, e o fuso deve ser, no futuro, o do local de onde a pessoa se loga. A decisão do [ADR 0045](../adr/0045-claims-tempos-e-sessao-diaria.md) não muda. **Pendência aberta:** usar o fuso do usuário logado. Falta decidir de onde ele vem (cadastro do usuário, da empresa ou do navegador) e como a meia-noite da sessão se comporta ao mudar de fuso. Pede novo ADR quando houver operação fora do Brasil. Acompanhada no [registro do Task 10](./task-10-convite-e-recuperacao-de-senha.md).
- **Teste de `store_data_at_delete` nas exclusões de `Usuario` e `EmpresaGestora`:** só a exclusão de `usuario_perfil` tem teste (`AuditoriaPerfilIT`). Ainda não existe código que exclua essas entidades, e a RLS recusaria a revisão `DEL` com `tenant_id` nulo, então o teste entra junto com a primeira exclusão.
- **Produção:** preencher `BOLETO_JWT_CHAVE_PRIVADA` pelo Secrets Manager (fora do escopo da Fase 1).
- Convite e "esqueci minha senha" ficam no Task 10 (feitos lá, ver o [registro do Task 10](./task-10-convite-e-recuperacao-de-senha.md)).
Pendências do Task 8 resolvidas aqui: o `ContextoTenant` é ligado pelo JWT validado; o contexto é propagado no executor `executorComContexto`; o `X-Tenant-Id` é ignorado em controller real (`TenantDoJwtIT` com `/auth/me`); `perfil*` e `usuario_perfil` são auditados; a exclusão (`DEL`) ganhou teste (`AuditoriaPerfilIT`). Seguem abertos os testes de `REQUIRES_NEW`, `readOnly` e concorrência com `@Version`.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-23 | ADRs 0044 a 0050, Compose e páginas de arquitetura no `boleto-docs` |
| 2026-11-23 | Autenticação, sessão, refresh, limites e testes no `boleto-backend` |
| 2026-11-23 | Correções da revisão: permissão reconferida no token de empresa assumida (`caadd34`), ADRs 0012 e 0046 (`6632d67`) e este registro |
| 2026-11-23 | Backend integrado (PR #8, `00da90b`), demonstração ao vivo no Compose, workflows registrados e Task 9 concluída |
| 2026-11-24 | Fuso `America/Sao_Paulo` confirmado pelo usuário (só Brasil por ora); evolução para o fuso do usuário logado registrada como pendência |
| 2026-11-23 | Autorização, assumir empresa, auditoria de perfis, regras ArchUnit, demonstração no Compose e este registro; falta o envio |
