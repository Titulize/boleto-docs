---
title: 'ADR 0002: Backend com Spring Boot, Java 25 e Gradle'
---

# ADR 0002: Backend com Spring Boot, Java 25 e Gradle

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O backend precisa de segurança, persistência, validação e observabilidade maduras, e rodar na AWS com imagem Amazon Linux.

## Decisão

- Spring Boot 4.1.x, que dá suporte de primeira classe ao Java 25.
- Java 25 (LTS) pelo Amazon Corretto, com suporte do fornecedor até 2032.
- Gradle com Kotlin DSL, usando o Gradle Wrapper com checksum de distribuição.
- Documentação da API com springdoc (OpenAPI e Swagger UI).

As versões exatas ficam no [`versions.toml`](../guias/versoes.md).

## Consequências

- Java 25 permite recursos recentes, e exige toolchain explícita no Gradle e imagens com Corretto 25.
- Spring Boot 4.2 já existe. Adotamos a 4.1 por ser a linha estável com patches e atualizamos de forma planejada.
- A compatibilidade de Spring Modulith e springdoc com a 4.1 é confirmada no esqueleto do backend.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Maven | Preferência por Gradle |
| Java 21 | O 25 é o LTS atual e foi o pedido |
| Quarkus ou Micronaut | A equipe e o ecossistema de segurança estão em Spring |
