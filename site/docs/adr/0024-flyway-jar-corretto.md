---
title: 'ADR 0024: Flyway pelo JAR sobre Amazon Corretto headless'
---

# ADR 0024: Flyway pelo JAR sobre Amazon Corretto headless

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O `versions.toml` fixava o Flyway pelo tarball do CLI oficial (`[tools.flyway]`, `url_linux_x64` e `sha256_linux_x64`). O tarball linux-x64 tem cerca de 585 MB descompactado, só existe para x64 e rodaria por emulação em máquinas ARM e no Fargate com Graviton. O [ADR 0010](./0010-imagens-amazon-linux.md) exige Amazon Linux 2023 para a imagem de migrações, e o backend já usa Amazon Corretto.

## Decisão

- **JAR sobre Corretto headless:** a imagem do `boleto-migrations` roda o Flyway com `java -cp "lib/*" <classe principal>`, sobre a imagem Amazon Corretto 25 headless (Amazon Linux 2023), pinada por digest. Os JARs vêm do Maven Central.
- **Build em dois estágios:** o estágio `baixar` (Amazon Linux por digest) baixa cada JAR e confere o sha256. O estágio final (Corretto headless por digest) só copia a pasta `lib/`. O `curl` fica fora da imagem final.
- **Lista no `versions.toml`:** `[tools.flyway]` tem `version`, `main_class` (`org.flywaydb.commandline.Main`) e a tabela `[tools.flyway.jars]`, com `group`, `artifact`, `version` e `sha256` por JAR. A URL do Maven Central é derivada desses campos. A lista mínima para PostgreSQL tem 24 JARs: `flyway-commandline`, núcleo, verbos (`info`, `migrate`, `validate`, `schemas`, `repair`, `baseline`), suporte ao PostgreSQL, driver `org.postgresql:postgresql` 42.7.14 e dependências de execução (Jackson, `jansi`, `checker-qual`).
- **Arquivo gerado:** a sincronização escreve `.platform/flyway-jars.lock`, uma linha por JAR (`sha256`, URL e nome do arquivo), que o estágio `baixar` lê. O `sync:check` falha se o arquivo for editado à mão.
- **Variáveis:** saem `FLYWAY_URL` e `FLYWAY_SHA256` e a entrada do tarball. Entram `FLYWAY_VERSION` e `FLYWAY_MAIN_CLASS`. O validador rejeita a entrada antiga, JAR sem sha256, versão em faixa e JAR repetido.
- **Como a lista foi obtida:** o `flyway-commandline` do Maven Central puxa todos os módulos de banco e de nuvem (a resolução completa traz muito mais que os 24 JARs da lista; a contagem exata não foi registrada). A lista foi montada excluindo as dependências transitivas dele e acrescentando só o que o PostgreSQL usa. A imagem rodou `info`, `migrate` (com callback `afterMigrate` e placeholders) e `validate` contra PostgreSQL 18.7. Cada sha256 foi conferido contra o `.sha1` ou `.sha256` publicado no Maven Central.
- **Caminho do Java:** a imagem headless não põe `java` no `PATH`. O entrypoint chama `$JAVA_HOME/bin/java`.
- **Squawk:** o `[tools.squawk]` (versão, URL e sha256 do binário linux-x64) entra no mesmo `versions.toml` para o lint de SQL ([ADR 0028](./0028-lint-sql-e-testes.md)).

## Consequências

- Os 24 JARs somam cerca de 6 MB (6.275.190 bytes, soma do `Content-Length` dos 24 arquivos no Maven Central em 2026-11-21; o CLI oficial tem cerca de 585 MB). A imagem roda em x64 e ARM com a mesma base do backend.
- Atualizar o Flyway passa a exigir regenerar a lista de JARs e os sha256. O Renovate não cobre essa tabela, então a atualização é manual e revisada.
- Módulos de Flyway não listados (nuvem, relatórios e outros bancos) não existem na imagem. A exceção é `flyway-database-cockroachdb`, que está na lista porque o suporte ao PostgreSQL do Flyway o traz como dependência. Uma funcionalidade que dependa deles falha em tempo de execução com `NoClassDefFoundError`. A demonstração e os testes do `boleto-migrations` cobrem os verbos usados.
- Um JAR novo exigido por uma versão futura do Flyway aparece como falha no teste da imagem, não em produção.
- A imagem de migração não tem shell de conveniência além do que o Corretto traz. O entrypoint é um script `sh` simples.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| CLI oficial do Flyway (tarball) | Cerca de 585 MB, só x64 e base diferente do backend. Em ARM, roda por emulação |
| Imagem `flyway/flyway` | Não é Amazon Linux e tem o mesmo tamanho do CLI |
| `flyway-commandline` com todas as dependências transitivas | Traz drivers de dezenas de bancos e SDKs de nuvem sem uso, o que aumenta a imagem e a superfície de ataque |
| Flyway embutido no backend (Spring Boot) | O backend teria DDL na conexão e a migração deixaria de ser o primeiro passo do deploy ([ADR 0027](./0027-migracao-primeiro-passo.md)) |
| Corretto JDK completo | Traz compilador e ferramentas que a execução não usa |
