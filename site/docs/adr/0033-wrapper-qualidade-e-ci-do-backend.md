---
title: 'ADR 0033: Wrapper, qualidade e CI do backend'
---
# ADR 0033: Wrapper, qualidade e CI do backend
- **Status:** Substituído em parte pelo [ADR 0036](./0036-schema-real-nos-testes-do-backend.md)
- **Data:** 2026-11-21

> **Substituído em parte pelo [ADR 0036](./0036-schema-real-nos-testes-do-backend.md):** os testes que sobem o Spring deixam de usar um PostgreSQL vazio com `@ServiceConnection`. Eles rodam a imagem real do `boleto-migrations` e conectam como `boleto_app`, e a CI constrói essa imagem pela composite action do `boleto-migrations`. O que não mudou: Wrapper, Node e formatador, Spotless, Jacoco, Ryuk desligado na CI e cache das imagens.
## Contexto
O backend precisa de build reprodutível, formatação e cobertura exigidas, testes com banco real e CI no estilo do `boleto-migrations`, sem custo e sem versão solta ([padrão do projeto](../guias/padrao-do-projeto.md), princípios 1 e 3).
## Decisão
**Gradle Wrapper.**
- O `gradle-wrapper.jar` não é gerado pela sincronização. Ele é criado uma vez com a distribuição oficial do Gradle 9.9.2 (conferida pelo `distribution_sha256` do `versions.toml`), e depois a sincronização restaura o `gradle-wrapper.properties` com o checksum. `gradlew` entra no git como executável e `gradlew.bat` com CRLF.
- A CI roda `gradle/actions/wrapper-validation` (fixada por SHA) para detectar um JAR adulterado.
**Node e formatador no alvo `backend` (tag `v0.5.0`).**
- O commitlint do backend precisa de Node exato. O alvo `backend` do `sync-versions.mjs` passou a gerar `.node-version` e a instalar `node` no `mise.toml`, e o `versions.toml` ganhou `google_java_format` em `[backend.tools]`. Foi o passo A0 do Task 7, publicado no `boleto-docs` (PR [#10](https://github.com/Titulize/boleto-docs/pull/10), tag `v0.5.0`).
- Repetir a versão do Node à mão no workflow violaria o princípio 3.
**Testes.**
- Só os testes que sobem o Spring usam PostgreSQL por Testcontainers (`@ServiceConnection`), com a imagem `POSTGRES_IMAGE` de `.platform/versions.env` (tag e digest). Os testes de Modulith e ArchUnit não sobem contêiner. Os testes não aplicam as migrações: o schema só existe no `boleto-migrations`, e o Task 8 decide como os testes o recebem.
- Na CI, `TESTCONTAINERS_RYUK_DISABLED=true` (o Ryuk vem do Docker Hub, com limite de pulls) e as imagens externas ficam em cache no padrão do [ADR 0021](./0021-cache-imagens-ci.md).
**Qualidade.**
- Spotless com `googleJavaFormat` na versão do `versions.toml` e formato básico para `.gitignore`, `.md` e `.yml`. Jacoco com limite de 80% de linhas ([ADR 0032](./0032-esqueleto-do-backend.md)).
- A CI constrói a imagem Docker sem publicar: a imagem quebra por Dockerfile, não por Java, e só a CI detecta isso.
**Execução local.**
- `mise.toml` dá Java 25 Corretto e Node. `./gradlew test` (Linux e macOS) e `.\gradlew.bat test` (Windows) funcionam com o Docker ativo. `bootRun` usa o profile `dev`. O Gradle não baixa JDK (`org.gradle.java.installations.auto-download=false`), conforme o [ADR 0011](./0011-ambiente-do-dev.md).
**Sem Renovate neste repositório.** Ele disputaria com o catálogo gerado.
## Consequências
- O JAR do wrapper é o único binário versionado que a sincronização não gera. A validação oficial na CI cobre o risco.
- Os testes ficam independentes do schema até o Task 8.
- Fica para o Task 14: smoke com migração e backend na CI, verificação de dependências do Gradle e publicação da imagem.
- No Windows, o `gradlew.bat` foi executado localmente. O `./gradlew` foi exercitado só no Docker e na CI (Linux).
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Não versionar o JAR do wrapper | O `gradlew` não funciona sem ele, e o dev precisaria do Gradle instalado |
| Repetir a versão do Node no workflow | Viola o princípio 3 e diverge do `versions.toml` |
| Banco em H2 nos testes | Diferente do PostgreSQL de produção, esconderia erro de RLS e de dialeto |
| Contêiner de teste por classe | Mais pulls contra o limite do `public.ecr.aws` e testes mais lentos |
