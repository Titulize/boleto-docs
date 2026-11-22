---
title: 'ADR 0036: Schema real do boleto-migrations nos testes do backend'
---

# ADR 0036: Schema real do `boleto-migrations` nos testes do backend

- **Status:** Aceito
- **Data:** 2026-11-22
- **Substitui em parte:** [ADR 0033](./0033-wrapper-qualidade-e-ci-do-backend.md) (parágrafo "Testes")

## Contexto

O [ADR 0033](./0033-wrapper-qualidade-e-ci-do-backend.md) deixou os testes do backend com um PostgreSQL vazio, sem o schema, e adiou a decisão para o Task 8. A partir do Task 8 o backend tem entidades, `@TenantId` e RLS, e testes sem o schema real não provam nada disso. O schema pertence só ao `boleto-migrations` ([padrão do projeto](../guias/padrao-do-projeto.md)), e o [ADR 0027](./0027-migracao-primeiro-passo.md) define a imagem de migração como o contrato de aplicação.

O `boleto-migrations` é privado. Na CI do `boleto-backend` o runner só faz checkout do próprio repositório, e a conta de organização é do plano gratuito.

## Decisão

**Os testes usam a imagem real de migração.**

- O Testcontainers sobe o PostgreSQL (imagem `POSTGRES_IMAGE`), roda a imagem do `boleto-migrations` uma vez, na mesma rede, e o Spring conecta como `boleto_app`, a role que produção usa. O superusuário de teste serve só para preparar e limpar dados.
- O `@ServiceConnection` saiu, porque ele sobrepõe `spring.datasource.*`. As propriedades vêm de um `DynamicPropertyRegistrar`.
- O backend não copia SQL do `boleto-migrations`.

**Local.** A tarefa Gradle `construirImagemMigracoes` (dependência do `test`) roda `docker build -t boleto-migrations:teste ../boleto-migrations`. Se a pasta não tiver `Dockerfile`, a tarefa aborta com mensagem que nomeia a pasta. `MIGRATIONS_CONTEXT` aponta outra pasta (necessário em worktree). `MIGRATIONS_IMAGE` indica uma imagem já construída e pula o build.

**CI.** O `boleto-migrations` ganhou a composite action `.github/actions/imagem-migracoes`: ela constrói a imagem a partir do próprio checkout da action (`$GITHUB_ACTION_PATH`) e devolve o output `imagem`. O `ci.yml` do backend usa a action fixada por SHA do commit (`15444e6`) e passa a imagem aos testes em `MIGRATIONS_IMAGE`. A `AL2023_IMAGE`, que a action baixa, entrou na lista de imagens em cache ([ADR 0021](./0021-cache-imagens-ci.md)).

**Acesso entre repositórios privados: nível da organização.** A configuração `Actions > Access` do `boleto-migrations` passou de `none` para `organization`, aplicada por `gh api -X PUT repos/Titulize/boleto-migrations/actions/permissions/access -f access_level=organization` e conferida com o `GET` (`access_level: organization`). A action roda sem token, sem PAT e sem chave de deploy, então não há segredo para guardar nem rotacionar.

## Consequências

- Os testes provam o schema real: `SchemaRealTest` confere o schema `boleto`, a `revinfo_seq` com `increment_by = 50`, 0 linhas fora de transação e a conexão como `boleto_app`. O `ddl-auto=validate` passa a validar as entidades contra as tabelas reais.
- Os testes do backend precisam do Docker e de `../boleto-migrations` (ou `MIGRATIONS_CONTEXT`).
- Todo bump da action exige trocar o SHA no `ci.yml` do `boleto-backend`. Uma migração nova só chega à CI do backend depois desse bump.
- **Custo aceito.** Workflows de qualquer repositório privado da organização podem usar a action e o conteúdo do `boleto-migrations`, e colaboradores desses repositórios o enxergam de forma indireta. A decisão vale enquanto a organização tiver só repositórios de confiança. Um repositório novo que não deva ver o schema exige reavaliar (alternativa B, abaixo).
- O primeiro run do PR do backend falhou porque o runner não tinha `../boleto-migrations` (task `construirImagemMigracoes`); a action corrigiu o problema (ver [registro do Task 8](../progresso/task-08-base-multitenant-auditoria.md)).
- A demonstração no runner foi o próprio CI do PR: a action foi resolvida sem token e a imagem foi usada nos testes.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Copiar o SQL do `boleto-migrations` para o backend | Duplica o schema e permite divergência, contra a regra de que o schema só pertence ao `boleto-migrations` |
| `ImageFromDockerfile` do Testcontainers | O `Dockerfile` usa `COPY --chmod`, que exige BuildKit |
| PAT ou chave de deploy para fazer checkout do `boleto-migrations` na CI | Exige criar e rotacionar um segredo. É a alternativa B, descartada porque o plano da organização permite o acesso por organização |
| Checkout do `boleto-migrations` por `actions/checkout` com token | Mesmo problema do segredo, e o repositório inteiro ficaria no runner do backend |
| Tornar o `boleto-migrations` público | O schema não deve ser exposto sem decisão própria |
| `@ServiceConnection` com superusuário | Os testes passariam como dono do banco e ignorariam a RLS |
| H2 ou PostgreSQL vazio | Não valida RLS, `@TenantId`, Envers nem o `validate` ([ADR 0033](./0033-wrapper-qualidade-e-ci-do-backend.md)) |
