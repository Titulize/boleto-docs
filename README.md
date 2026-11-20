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
| Docker Compose de desenvolvimento | `compose/` | Task 5 |
| Padrão do projeto (regras e definição de pronto) | `site/docs/guias/padrao-do-projeto.md` | pronto |
| Registro de progresso das tarefas | `site/docs/progresso/` | pronto |

## Versões centrais

`versions.toml` é a única fonte das versões usadas na plataforma (Java, Node, Gradle, Flyway, imagens Docker e bibliotecas).

- Toda versão é exata. Sem faixas (`^`, `~`, `*`), sem `latest`.
- Toda imagem Docker tem tag e digest. Todo download tem URL e sha256.
- As imagens do backend, do frontend e do Flyway partem do Amazon Linux 2023.
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

Veja [Ambiente do desenvolvedor](site/docs/guias/ambiente-do-dev.md) para as opções e os pontos de atenção.

## Documentação

O site (Docusaurus, com ADRs, diagramas C4 em Mermaid e guias) fica em `site/` e roda em um container Amazon Linux 2023.

```bash
docker compose up docs   # http://localhost:3000/boleto-docs/
```

- A primeira subida instala as dependências e leva alguns minutos.
- Links quebrados falham o build (`npm run build` dentro de `site/`).
- A publicação no GitHub Pages é feita pela pipeline a cada push na `main` que altera `site/`.
- Para propor uma decisão de arquitetura, copie `site/docs/adr/0000-modelo.md`.

## Contribuindo

Siga o [Padrão do projeto](site/docs/guias/padrao-do-projeto.md). Em resumo:

- Commits seguem [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), por exemplo `feat(versions): atualiza Gradle para 9.9.2`. A CI valida as mensagens dos commits de cada PR.
- Trabalho em branch e PR. O PR só é integrado com todos os workflows verdes.
- Antes de enviar, rode localmente as verificações da tabela "Antes de enviar" do padrão.
- Uma mudança em `versions.toml` gera uma nova tag.
- Toda tarefa que avança atualiza o [registro de progresso](site/docs/progresso/index.md), os guias afetados e os READMEs.

## Custos

O repositório é público para usar GitHub Pages e branch protection sem custo. Os outros três repositórios são privados e usam a cota gratuita de minutos do GitHub Actions da organização.
