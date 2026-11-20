# Código de terceiros embarcado

| Arquivo | Origem | Versão | Licença |
|---|---|---|---|
| `smol-toml.cjs` | [smol-toml](https://github.com/squirrelchat/smol-toml), arquivo `dist/index.cjs` | 1.9.1 | BSD-3-Clause (`smol-toml.LICENSE`) |

O parser TOML é embarcado para que os scripts de versões rodem em qualquer repositório sem `node_modules`.
Estes arquivos são copiados para `.platform/` dos outros repositórios pelo comando `init` e `update` do `sync-versions.mjs`.
Para atualizar, copie o `dist/index.cjs` da nova versão e ajuste a tabela acima.
