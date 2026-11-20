# boleto-docs

Repositório de plataforma da Titulize (controle de boletos, remessas e retornos CNAB).
Reúne o que é compartilhado entre `boleto-backend`, `boleto-frontend` e `boleto-migrations`.

| Conteúdo | Onde | Situação |
|---|---|---|
| Versões centrais pinadas | `versions.toml` | pronto |
| Validação das versões | `scripts/validate-versions.mjs` | pronto |
| Site de documentação (Docusaurus) | `site/` | pronto |
| Sincronização de versões nos outros repositórios | `scripts/` | Task 3 |
| Scripts de bootstrap do ambiente do dev | `bootstrap/` | Task 4 |
| Docker Compose de desenvolvimento | `compose/` | Task 5 |

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
npm run validate   # valida o versions.toml
npm test           # testes do validador
```

Requer Node 24.15 ou superior (o projeto usa o Node 26 LTS).

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

- Commits seguem [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), por exemplo `feat(versions): atualiza Gradle para 9.9.2`. A CI valida as mensagens dos commits de cada PR.
- Uma mudança em `versions.toml` altera a versão do repositório, então gera uma nova tag.
- Alterações em `main` passam por PR.

## Custos

O repositório é público para usar GitHub Pages e branch protection sem custo. Os outros três repositórios são privados e usam a cota gratuita de minutos do GitHub Actions da organização.
