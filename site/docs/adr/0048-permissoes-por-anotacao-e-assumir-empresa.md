---
title: 'ADR 0048: Permissões por anotação e assumir empresa'
---
# ADR 0048: Permissões por anotação e assumir empresa
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O catálogo de telas e as permissões por perfil existem desde a V1. Falta aplicá-los nas rotas e permitir que a empresa gestora da plataforma atue em nome de uma empresa cliente.
## Decisão
- A anotação `@RequerPermissao(tela = Telas.USUARIOS, acao = Acao.VISUALIZAR)` fica em `shared.seguranca`. É uma meta-anotação sobre `@PreAuthorize("@autorizacao.permite('{tela}','{acao}')")`.
- `Acao` vale `VISUALIZAR`, `INCLUIR`, `ALTERAR` ou `EXCLUIR`. `Telas` reúne constantes com os códigos do catálogo da V1.
- O bean `autorizacao` (módulo `auth`) confere authorities no formato `TELA:ACAO`, montadas a cada requisição a partir de `usuario_perfil` e `perfil_tela_permissao`. A leitura roda sob o contexto da **origem**, porque as linhas do usuário estão no tenant dele.
- **Padrão negar:** rota sem anotação exige só autenticação, e uma regra do ArchUnit exige `@RequerPermissao` em todo mapeamento fora de `auth`.
- Respostas: 401 `NAO_AUTENTICADO` sem token válido e 403 `SEM_PERMISSAO` sem a permissão.
- **`POST /auth/assumir-empresa`** exige `PLATAFORMA_EMPRESAS` com `VISUALIZAR`. Confere que a empresa existe e está ativa e devolve um novo access token com `tid` da empresa e `tor` da plataforma, com o mesmo `sid` e o mesmo `exp`. Não devolve refresh. O refresh devolve sempre o tenant de origem.
## Consequências
- Esquecer a anotação em uma rota nova quebra o build, em vez de abrir a rota.
- Trocar o perfil de alguém vale na próxima requisição.
- O token com empresa assumida (`tid` diferente de `tor`) reconfere `PLATAFORMA_EMPRESAS:VISUALIZAR` a cada requisição: quem perde essa permissão recebe 401 na requisição seguinte, sem esperar o `exp`.
- O token com empresa assumida morre com a sessão e não pode ser renovado: para continuar, a pessoa assume a empresa de novo com o access da origem.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Regras por rota em `SecurityFilterChain` | Separa a regra do método e é fácil esquecer uma rota |
| Permissões no token | Ficam velhas até o token expirar ([ADR 0045](./0045-claims-tempos-e-sessao-diaria.md)) |
| Cabeçalho `X-Tenant-Id` para atuar em outra empresa | O cliente escolheria o tenant; ver o [ADR 0050](./0050-contexto-de-tenant-jwt-e-threads.md) |
