---
title: 'ADR 0032: Esqueleto do backend'
---
# ADR 0032: Esqueleto do backend
- **Status:** Aceito
- **Data:** 2026-11-21
## Contexto
O Task 7 entrega um backend que sobe, responde `/actuator/health` e mostra o Swagger, sem regra de negócio. Era preciso decidir o que o esqueleto conecta, como os módulos do [ADR 0003](./0003-monolito-modular.md) são testados desde o começo e quando a documentação da API fica exposta. O [ADR 0002](./0002-backend-spring-java-gradle.md) exige confirmar a compatibilidade de Spring Modulith e springdoc com o Spring Boot 4.1.
## Decisão
**Conexões.**
- O esqueleto conecta no PostgreSQL como `boleto_app`, com `spring.jpa.hibernate.ddl-auto=validate`. Isso prova o contrato do [ADR 0027](./0027-migracao-primeiro-passo.md): o backend só sobe com o schema e a role que a migração criou. URL, usuário e senha vêm só de `SPRING_DATASOURCE_*`, sem senha no `application.yml`.
- Sem entidades, o `validate` ainda não valida nenhuma tabela. A validação de verdade começa no Task 8.
- Não conecta no Valkey e não tem Flyway no classpath (o ArchUnit proíbe `org.flywaydb`). Valkey, Lettuce e Bucket4j entram no Task 9, com o refresh rotativo e o rate limit.
- `/actuator/health` mostra `status` e `components` (`db`, `diskSpace`, `ping` e os de liveness e readiness), sem `details`. O Actuator expõe só `health` e `info`.
**Módulos.**
- Pacote raiz `br.com.titulize.boleto`, com os subpacotes `auth`, `usuarios`, `empresas`, `auditoria` e `shared`, cada um com `package-info.java` e `@ApplicationModule(allowedDependencies = ...)`.
- Dependências: `auth` usa `usuarios`, `usuarios` usa `empresas`, `auditoria` usa `usuarios`, e todos usam `shared` (módulo aberto). Ver [Módulos do backend](../arquitetura/modulos-backend.md).
- `ModulosTest` chama `ApplicationModules.of(BoletoApplication.class).verify()` e confere a lista exata de módulos. `ArquiteturaTest` (ArchUnit) proíbe ciclos entre fatias, `org.flywaydb` e `@Autowired` em campo.
**Documentação da API.**
- `springdoc.api-docs.enabled` e `springdoc.swagger-ui.enabled` valem `false` por padrão. O profile `dev` do `bootRun` e o [Compose](../guias/compose-dev.md) os ligam. Sem Spring Security neste task (Task 9), a documentação não pode ficar aberta fora do desenvolvimento.
**Cobertura.**
- Jacoco com mínimo de 80% de linhas, sem `BoletoApplication`, ligado ao `check`. O valor fica em `gradle.properties` (`jacocoMinLineCoverage`).
## Compatibilidade com o Spring Boot 4.1 (confirmada)
O [ADR 0002](./0002-backend-spring-java-gradle.md) deixou a compatibilidade para este task. Resultado, com as versões resolvidas pelo catálogo e pelos BOMs:
| Componente | Versão | Origem |
|---|---|---|
| Spring Boot | 4.1.3 | `versions.toml`, plugin `org.springframework.boot` |
| Spring Modulith | 2.1.3 | BOM `spring-modulith-bom` |
| springdoc (`springdoc-openapi-starter-webmvc-ui`) | 3.2.0 | `versions.toml` |
| ArchUnit | 1.5.1 | `versions.toml` |
| Jacoco | 0.8.16 | `versions.toml` |
Provas:
- O contexto sobe com Spring Boot 4.1.3, Modulith 2.1.3 e springdoc 3.2.0 no classpath (`BoletoApplicationTests`).
- `ModulosTest` (Modulith) verifica ciclos, acesso a tipos internos e dependências não declaradas sem erro.
- `DocumentacaoApiTest`: com as propriedades ligadas, `/v3/api-docs` e `/swagger-ui/index.html` respondem 200; sem elas, 404.
- A CI do PR e da `main` do `boleto-backend` passou (build, testes, Spotless, Jacoco e imagem) e a demonstração pelo Compose respondeu `/actuator/health` 200 com `status` UP, `/v3/api-docs` 200 e `/swagger-ui/index.html` 200 ([registro do Task 7](../progresso/task-07-esqueleto-backend.md)).
Nenhuma incompatibilidade apareceu, então nenhuma versão mudou.
## Consequências
- Os limites dos módulos ficam testados antes de existir regra de negócio.
- O health mostra o banco, então o `--wait` do Compose só considera o backend saudável se a conexão com `boleto_app` funcionar.
- `/swagger-ui` sozinho responde 404. O endereço da interface é `/swagger-ui/index.html`, e `/swagger-ui.html` redireciona para ele.
- Quem rodar a imagem fora do Compose sem as variáveis do springdoc não terá Swagger. É o comportamento seguro desejado.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Conectar também no Valkey agora | Seria dependência sem uso, e o health passaria a depender dele. Entra no Task 9 |
| Sem banco no esqueleto | Não provaria o contrato do ADR 0027 nem a role `boleto_app` |
| Swagger ligado por padrão | Sem autenticação ainda, exporia a API fora do dev |
| Módulos só por convenção de pacote | O Modulith e o ArchUnit transformam a regra em teste que falha |