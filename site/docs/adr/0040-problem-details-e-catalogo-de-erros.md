---
title: 'ADR 0040: Problem Details e catálogo de erros'
---

# ADR 0040: Problem Details e catálogo de erros

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

A API precisa de um formato único de erro, que o frontend consiga tratar por código e que não vaze dado pessoal nem a causa interna. O PostgreSQL devolve, na violação de unicidade, uma mensagem com o valor (por exemplo o e-mail), e o [ADR 0015](./0015-lgpd.md) proíbe dado pessoal fora dos lugares previstos.

## Decisão

- **RFC 9457.** Um `@RestControllerAdvice` (`ManipuladorDeErros`) estende `ResponseEntityExceptionHandler` e responde `application/problem+json`. A propriedade `spring.mvc.problemdetails.enabled` não é ligada, porque registraria um segundo advice. Erros herdados (405, 415) saem no mesmo formato.
- **Campos.** `type`, `title`, `status`, `detail`, mais `codigo` e `traceId` ([ADR 0041](./0041-logs-json-com-traceid.md)). O `type` é a URL da seção do código em [Erros da API](../arquitetura/erros-da-api.md), com a base em `boleto.erros.tipo-base` (`https://titulize.github.io/boleto-docs/arquitetura/erros-da-api`).
- **Validação.** Traz `erros[{campo, mensagem}]`, sem o valor rejeitado.
- **Catálogo inicial (`CodigoErro`).** `VALIDACAO` 400, `REQUISICAO_INVALIDA` 400, `NAO_ENCONTRADO` 404, `CONFLITO` 409, `VERSAO_DESATUALIZADA` 409 e `ERRO_INTERNO` 500. Os códigos de autenticação e permissão chegam no Task 9.
- **Texto fixo para o que pode vazar.** `CONFLITO` (violação de unicidade, SQLState `23505`) responde "Já existe um registro com os mesmos dados." e nunca a mensagem do PostgreSQL. `ERRO_INTERNO` responde um detalhe fixo e pede o `traceId`. A causa não vai ao cliente.
- **Erros de negócio.** `ErroNegocio` leva um `CodigoErro` e uma mensagem escrita pelo servidor.

## Consequências

- O cliente trata o erro pelo campo `codigo`, não pelo texto.
- O custo do `ERRO_INTERNO`: o log registra só a classe da exceção, sem causa nem pilha (ver [ADR 0041](./0041-logs-json-com-traceid.md)).
- Cada código novo exige uma linha na página [Erros da API](../arquitetura/erros-da-api.md), porque o `type` aponta para ela.
- Testado no `ProblemDetailsTest`: 400 de validação sem o valor rejeitado, 404, 409 de e-mail duplicado sem o e-mail no corpo nem no log, 409 de versão, 500 sem causa, 405 e 415 no mesmo formato, e `traceId` do corpo igual ao cabeçalho `X-Trace-Id`.
- A base do `type` depende de a página existir no endereço publicado: o `baseUrl` do site é `/boleto-docs/`.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Formato próprio de erro | Perde o padrão RFC 9457 e as ferramentas que o entendem |
| `spring.mvc.problemdetails.enabled` | Registra um segundo advice que disputa com o `ManipuladorDeErros` |
| Devolver a mensagem da exceção | Vaza e-mail (PostgreSQL) e detalhes internos |
