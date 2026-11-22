---
title: 'ADR 0041: Logs JSON com traceId'
---

# ADR 0041: Logs JSON com `traceId`

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

O [ADR 0014](./0014-observabilidade.md) pede logs estruturados com identificador de rastreio, e o [ADR 0015](./0015-lgpd.md) proíbe dado pessoal neles. O Task 11 liga o Micrometer Tracing.

## Decisão

- **Logging estruturado nativo do Spring Boot**, `logging.structured.format.console: logstash`, em todos os profiles (um só caminho testado). Nenhuma dependência nova. Para ler: `docker compose logs backend | jq`.
- **`TraceIdFilter`** (ordem mais alta) gera 16 bytes aleatórios em hexadecimal, grava no MDC como `traceId`, devolve em `X-Trace-Id` e limpa no `finally`. **Não aceita id vindo do cliente**, para não permitir forjar nem injetar texto em log. O Task 11 troca a origem pelo Micrometer Tracing, que usa a mesma chave `traceId`.
- **Sem dado pessoal nos logs.** `Usuario.toString` só traz ids, não há `show_sql` nem log de binds, e o logger `org.hibernate.engine.jdbc.spi.SqlExceptionHelper` fica em `OFF`, porque o PostgreSQL devolve `Key (email)=(...)` na violação de unicidade. O erro interno registra só a classe da exceção.

## Consequências

- **Custo aceito:** com o `SqlExceptionHelper` em `OFF` para todo o aplicativo, falhas SQL inesperadas (deadlock, conexão, permissão) ficam sem mensagem, e o erro interno não traz pilha. A investigação depende do `traceId` e da classe. Se isso atrapalhar a operação, uma alternativa é registrar o `SQLState` (não é dado pessoal), em um novo ADR.
- O `LogsJsonTest` prova que uma linha de log durante a requisição é JSON válido com `traceId`, e que nome e e-mail conhecidos não aparecem na saída depois de criar e alterar um usuário. O `ProblemDetailsTest` prova o mesmo para o conflito de e-mail.
- Em desenvolvimento a saída também é JSON. Quem prefere texto usa `jq`.
- O `traceId` do cabeçalho enviado pelo cliente é ignorado.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Logstash Logback Encoder | Dependência extra que o Spring Boot já cobre |
| Texto no dev e JSON em produção | Dois caminhos, e só um seria testado |
| Aceitar `X-Trace-Id` do cliente | Permite forjar o id e injetar conteúdo no log |
| Logar a pilha completa com a causa | A mensagem das causas pode trazer dado pessoal |
