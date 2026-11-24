# boleto-docs

Repositório de plataforma da Titulize (controle de boletos, remessas e retornos CNAB).
Reúne o que é compartilhado entre `boleto-backend`, `boleto-frontend` e `boleto-migrations`.

| Conteúdo | Onde | Situação |
|---|---|---|
| Versões centrais pinadas | `versions.toml` | pronto |
| Validação das versões | `scripts/validate-versions.mjs` | pronto |
| Site de documentação (Docusaurus) | `site/` | pronto |
| Sincronização de versões nos outros repositórios | `scripts/sync-versions.mjs` | pronto |
| Scripts de bootstrap do ambiente do dev | `bootstrap/` | pronto |
| Docker Compose de desenvolvimento (`docker compose up -d` sobe PostgreSQL, Valkey, Mailpit, a migração e o backend; o site fica no profile `docs`) | `docker-compose.yml` | pronto |
| Flyway por JAR e Squawk nas versões centrais (alvo `migrations`, tag `v0.4.0`) | `versions.toml`, `scripts/sync-versions.mjs` | pronto |
| Node e google-java-format no alvo `backend` da sincronização (tag `v0.5.0`) | `versions.toml`, `scripts/sync-versions.mjs` | pronto |
| Imagem do Mailpit no alvo `backend` da sincronização, para os testes de e-mail do backend (tag `v0.6.0`) | `scripts/sync-versions.mjs` | pronto |
| Serviço `backend` no Compose (API Spring Boot do repositório `boleto-backend`, sobe no `up` padrão desde o ADR 0035) | `docker-compose.yml`; guia em `site/docs/guias/compose-dev.md` | pronto (Task 7) |
| Schema do banco, imagem de migração e testes de isolamento por tenant | repositório `boleto-migrations` (privado); guia em `site/docs/guias/migracoes.md` e modelo em `site/docs/arquitetura/modelo-de-dados.md` | pronto (Task 6, V1) |
| Registro da base multi-tenant e auditoria do backend (contexto de tenant, Envers, Problem Details, logs JSON, V2 do schema) e ADRs 0036 a 0042 | `site/docs/progresso/task-08-base-multitenant-auditoria.md`, `site/docs/arquitetura/multitenancy-e-auditoria.md` e `site/docs/arquitetura/erros-da-api.md` | concluída (Task 8) |
| Autenticação e autorização (JWT ES256, refresh no Valkey, sessão diária, limites, permissões por tela, assumir empresa, admin inicial), ADRs 0044 a 0050 e o backend do Compose ligado ao Valkey | `site/docs/arquitetura/autenticacao.md`, `site/docs/progresso/task-09-autenticacao-autorizacao.md` e `docker-compose.yml` | concluída (Task 9) |
| Convite de usuário e "esqueci minha senha" (tokens, política de senha, e-mail por SMTP, CPF cifrado, máscara nos logs, V3), ADRs 0051 a 0056, inventário LGPD e o backend do Compose ligado ao Mailpit e às chaves de dev | `site/docs/progresso/task-10-convite-e-recuperacao-de-senha.md`, `site/docs/guias/convite-e-senha.md`, `site/docs/guias/chaves-de-cpf.md`, `site/docs/arquitetura/inventario-lgpd.md` e `docker-compose.yml` | concluída (Task 10) |
| Padrão do projeto (regras e definição de pronto) | `site/docs/guias/padrao-do-projeto.md` | pronto |
| Registro de progresso das tarefas | `site/docs/progresso/` | pronto |

## Versões centrais

`versions.toml` é a única fonte das versões usadas na plataforma (Java, Node, Gradle, Flyway, imagens Docker e bibliotecas).

- Toda versão é exata. Sem faixas (`^`, `~`, `*`), sem `latest`.
- Toda imagem Docker tem tag e digest. Todo download tem URL e sha256.
- As imagens do backend, do frontend e das migrações partem do Amazon Linux 2023. O Flyway entra como JAR sobre o Corretto headless, com o sha256 de cada JAR no `versions.toml` ([ADR 0024](site/docs/adr/0024-flyway-jar-corretto.md)).
- Cada mudança recebe uma tag `vX.Y.Z`. Os outros repositórios fixam uma tag e nunca leem a `main`.
- O Renovate abre os PRs de atualização. Digests e checksums de downloads exigem revisão manual.

### Validar

```bash
npm ci
npm run validate     # valida o versions.toml
npm run sync         # regenera arquivos derivados deste repositório
npm run sync:check   # falha se houver divergência (usado na CI)
npm test             # testes dos scripts
```

Os outros repositórios usam o mesmo script. Veja [Versões centrais](site/docs/guias/versoes.md).

Requer Node 24.15 ou superior (o projeto usa o Node 26 LTS).

## Ambiente do desenvolvedor

Requisito mínimo: Docker com Compose e Git. O script instala Java 25, Node e as extensões do Kiro e do VS Code, nas versões do `versions.toml`.

```powershell
.\bootstrap\bootstrap.ps1                              # Windows: instala (sem administrador)
.\bootstrap\bootstrap.ps1 install -InstallDir C:\dev\tools   # instala tudo em uma pasta sua
.\bootstrap\bootstrap.ps1 doctor                       # diagnostica, sem alterar nada
```

```bash
bootstrap/bootstrap.sh             # Linux e macOS: instala
bootstrap/bootstrap.sh doctor      # diagnostica, sem alterar nada
```

O `install` também grava o hook Git `commit-msg` (commitlint) nos repositórios `boleto-docs`, `boleto-backend`, `boleto-migrations` e `boleto-frontend` que estiverem ao lado deste, inclusive para os worktrees. O `doctor` mostra o estado do hook.

Veja [Ambiente do desenvolvedor](site/docs/guias/ambiente-do-dev.md) para as opções e os pontos de atenção.

## Compose de desenvolvimento

A aplicação inteira local (PostgreSQL, Valkey, Mailpit, migração e backend), nas versões do `versions.toml`, com portas só em `127.0.0.1`. Precisa dos repositórios `boleto-backend` e `boleto-migrations` ao lado deste. Só comandos padrão do Docker Compose, na raiz do repositório, sem `-f`, sem profile e sem scripts:

```bash
docker compose up -d           # sobe infraestrutura, migração e backend (constrói as imagens no 1º uso)
docker compose up -d --build   # depois de mudar código do backend ou das migrações
docker compose down            # derruba tudo e mantém os dados
docker compose down -v         # derruba tudo e apaga os dados
docker compose ps
docker compose logs -f backend
```

Health em `http://localhost:8080/actuator/health`, Swagger em `http://localhost:8080/swagger-ui.html` e interface do Mailpit em http://localhost:8025. Sem `../boleto-backend` ou `../boleto-migrations`, o Compose para com `unable to prepare context: path "..." not found`: clone o que falta ou defina `BACKEND_CONTEXT` e `MIGRATIONS_CONTEXT` (obrigatório em worktree). Credenciais e portas têm valor padrão no `docker-compose.yml`. O `.env` é opcional (modelo em `.env.example`). As imagens ficam no bloco gerado do próprio arquivo, escrito por `npm run sync`. Testes sem Docker: `npm test`. Veja [Compose de desenvolvimento](site/docs/guias/compose-dev.md).

Só a infraestrutura (a CI do `boleto-docs` usa este comando, sem acesso aos repositórios privados) ou só a migração (guia: [Migrações do banco](site/docs/guias/migracoes.md)):

```bash
docker compose up -d --wait postgres valkey mailpit   # só PostgreSQL, Valkey e Mailpit
docker compose run --build --rm flyway                # só a migração (código ≠ 0 em qualquer erro)
```

Para subir sem tocar no ambiente que já roda, use `-p <nome>` e outras portas (guia: [Compose de desenvolvimento](site/docs/guias/compose-dev.md#sem-tocar-no-ambiente-que-já-roda)). Decisão: [ADR 0035](site/docs/adr/0035-compose-sobe-a-aplicacao-inteira.md).
## Documentação

O site (Docusaurus, com ADRs, diagramas C4 em Mermaid e guias) fica em `site/` e roda em um container Amazon Linux 2023.

```bash
docker compose --profile docs up -d --wait docs   # http://localhost:3000/boleto-docs/ (profile docs)
```

- Para parar o site, use `docker compose --profile docs down`.
- A primeira subida instala as dependências e leva alguns minutos.
- Links quebrados falham o build (`npm run build` dentro de `site/`).
- A publicação no GitHub Pages é feita pela pipeline a cada push na `main` que altera `site/`.
- Para propor uma decisão de arquitetura, copie `site/docs/adr/0000-modelo.md`.

## Contribuindo

Siga o [Padrão do projeto](site/docs/guias/padrao-do-projeto.md). Em resumo:

- Commits seguem [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), por exemplo `feat(versions): atualiza Gradle para 9.9.2`. A CI valida as mensagens dos commits de cada PR.
- O `bootstrap install` ativa a verificação da mensagem no commit (hook `commit-msg`, [ADR 0043](site/docs/adr/0043-hook-commit-msg.md)).
- Trabalho em branch e PR. O PR só é integrado com todos os workflows verdes.
- Antes de enviar, rode localmente as verificações da tabela "Antes de enviar" do padrão, inclusive `npx commitlint --from origin/main --to HEAD`.
- Uma mudança em `versions.toml` gera uma nova tag.
- Toda tarefa que avança atualiza o [registro de progresso](site/docs/progresso/index.md), os guias afetados e os READMEs.

## Custos

O repositório é público para usar GitHub Pages e branch protection sem custo. Os outros três repositórios são privados e usam a cota gratuita de minutos do GitHub Actions da organização.
