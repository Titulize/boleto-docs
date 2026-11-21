---
sidebar_position: -1
title: Padrão do projeto
---

# Padrão do projeto

Regras que valem para todos os repositórios e para qualquer pessoa ou agente (Kiro) que trabalhe no projeto. O Kiro carrega este arquivo em toda conversa pelo steering `padrao-projeto`.

## Princípios

1. **Custo zero em desenvolvimento.** Só ferramentas gratuitas e de código aberto. Nenhum serviço pago de nuvem nesta fase. Para a AWS, a opção de menor custo (ver [Custos](./custos.md)).
2. **Sem administrador.** Scripts e ferramentas do dev rodam com o usuário comum. Se algo exigir elevação, o script avisa e não tenta elevar.
3. **Versões exatas.** Toda versão sai do [`versions.toml`](./versoes.md). Imagens por tag e digest, downloads com sha256, GitHub Actions fixadas por SHA do commit.
4. **Imagens Amazon Linux 2023** para backend, frontend, migrações e documentação (ver [ADR 0010](../adr/0010-imagens-amazon-linux.md)).
5. **Documentação viva.** Nenhuma tarefa termina sem a documentação e os READMEs atualizados.

## Escrita

- Documentação, mensagens de script e textos de interface em português do Brasil. Nomes de código (classes, variáveis, arquivos) em inglês ou português, seguindo o que o repositório já usa.
- Frases diretas, uma ideia por frase. Números, comandos e caminhos exatos em vez de descrições vagas.
- Ao relatar resultado, dizer o que foi verificado e o que não foi. Falhas, inclusive as já corrigidas, são relatadas.

## Repositórios

| Repositório | Responsabilidade |
|---|---|
| `boleto-docs` (público) | `versions.toml`, sincronização de versões, bootstrap do ambiente, Compose de desenvolvimento, site de documentação e ADRs |
| `boleto-backend` | API Spring Boot |
| `boleto-frontend` | SPA Angular |
| `boleto-migrations` | Todo o schema do banco (Flyway) |

O `boleto-docs` é público: nunca colocar segredos, nomes de clientes ou dados internos nele.

## Versões

- Mudou uma versão? Altere o `versions.toml`, rode `npm run validate`, `npm run sync` e `npm test`, e crie uma tag `vX.Y.Z` depois do merge.
- Nunca edite arquivos gerados à mão: `.platform/`, `mise.toml`, `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties`, `.node-version` e os blocos `# >>> platform-versions` dos Dockerfiles.

## Git

- Commits em [Conventional Commits](./commits-e-releases.md). Título e linhas do corpo com no máximo 100 caracteres (regra do commitlint).
- **Trabalho em branch e PR.** Nada vai direto para a `main`. O PR só é integrado com todos os workflows verdes. O nome da branch segue o tipo do commit: `feat/...`, `fix/...`, `docs/...`.
- Integração por squash, com título no formato Conventional Commits.

## Antes de enviar (verificação local)

Rode localmente as mesmas verificações da CI do repositório alterado. No `boleto-docs`:

| Mudou | Rode |
|---|---|
| qualquer coisa (mensagens de commit) | `npx commitlint --from origin/main --to HEAD` |
| `versions.toml` ou `scripts/` | `npm run validate`, `npm run sync:check`, `npm test` |
| `bootstrap/bootstrap.sh` | `docker run --rm -v "<repo>:/mnt:ro" koalaman/shellcheck:stable --shell=bash /mnt/bootstrap/bootstrap.sh` |
| `bootstrap/*.ps1` | verificação de sintaxe (parser do PowerShell) e `bootstrap/tests/path.tests.ps1` no PowerShell 7 e no Windows PowerShell 5.1 |
| `site/` | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` (links quebrados falham) |

Os outros repositórios documentam suas verificações no próprio README.

## Depois de enviar

- Acompanhe **todos** os workflows disparados (não só o principal) até terminarem.
- Se algum falhar, corrija na mesma branch antes de integrar e registre a falha no relatório.

## Definição de pronto de uma tarefa

Uma tarefa do plano só é marcada como concluída quando:

1. o código e os testes estão no repositório, com a demonstração da tarefa executada;
2. as verificações locais e todos os workflows da CI passaram;
3. a documentação foi atualizada conforme a seção abaixo;
4. os READMEs afetados foram atualizados;
5. o `tasks.md` reflete o estado real (feito, pendente e o motivo).

Uma tarefa com algo pendente continua aberta (`[ ]`), com a pendência escrita.

## Atualização da documentação

Toda vez que uma tarefa do `tasks.md` avança ou é concluída:

1. **Registro de progresso.** Crie ou atualize a página da tarefa em `site/docs/progresso/` (`task-NN-nome.md`, seguindo o [modelo](../progresso/modelo.md)) e a linha dela no [índice](../progresso/index.md). A página registra data, situação, o que foi entregue, como foi verificado, falhas encontradas e pendências.
2. **Guias e arquitetura.** Atualize as páginas de `guias/` e `arquitetura/` cujo conteúdo mudou. Comandos, opções e caminhos citados precisam funcionar como estão escritos.
3. **Decisões.** Se uma decisão mudou, crie um novo ADR e marque o anterior como substituído. Um ADR aceito só recebe ajustes de redação ou consequências descobertas depois, nunca uma decisão diferente.
4. **READMEs.** Atualize o README de cada repositório afetado: tabela de conteúdo e situação, comandos de uso e de verificação. Um repositório que ganhou código pela primeira vez ganha um README.
5. **Build da documentação.** Rode o build do site localmente antes de enviar.
6. **`tasks.md`.** Atualize a tarefa com o que foi feito e o que falta.
