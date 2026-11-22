---
sidebar_position: 6
title: Erros da API
---

# Erros da API

Toda resposta de erro da API usa Problem Details ([RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)), com `Content-Type: application/problem+json`. Decisão no [ADR 0040](../adr/0040-problem-details-e-catalogo-de-erros.md). O campo `type` de cada erro aponta para a seção do código nesta página.

## Formato

Exemplo ilustrativo (os valores são de exemplo; ainda não há endpoint de negócio):

```json
{
  "type": "https://titulize.github.io/boleto-docs/arquitetura/erros-da-api#validacao",
  "title": "Dados inválidos",
  "status": 400,
  "detail": "Um ou mais campos são inválidos.",
  "codigo": "VALIDACAO",
  "traceId": "3f2a9c1e5b7d4a60918c2e4f6a8b0d12",
  "erros": [{ "campo": "email", "mensagem": "deve ser um endereço de e-mail válido" }]
}
```

| Campo | Significado |
|---|---|
| `type` | URL desta página com a âncora do código, em minúsculas (base em `boleto.erros.tipo-base`) |
| `title` | Título fixo do código |
| `status` | Status HTTP |
| `detail` | Texto para a pessoa. Nunca traz a mensagem do banco nem a causa interna |
| `codigo` | Código estável. O cliente trata o erro por ele, não pelo texto |
| `traceId` | Identificador da requisição, o mesmo do cabeçalho `X-Trace-Id` e dos logs ([ADR 0041](../adr/0041-logs-json-com-traceid.md)). Informe-o ao suporte |
| `erros` | Só em `VALIDACAO`: lista de `campo` e `mensagem`, sem o valor enviado |

O servidor gera o `traceId`. O cabeçalho `X-Trace-Id` enviado pelo cliente é ignorado.

## Catálogo

| Código | Status | Quando |
|---|---|---|
| [`VALIDACAO`](#validacao) | 400 | Corpo com campo inválido |
| [`REQUISICAO_INVALIDA`](#requisicao_invalida) | 400 | Requisição malformada ou erro de protocolo (por exemplo 405 e 415) |
| [`NAO_ENCONTRADO`](#nao_encontrado) | 404 | Recurso inexistente (ou de outro tenant) |
| [`CONFLITO`](#conflito) | 409 | Violação de unicidade |
| [`VERSAO_DESATUALIZADA`](#versao_desatualizada) | 409 | O registro mudou desde a leitura (bloqueio otimista) |
| [`ERRO_INTERNO`](#erro_interno) | 500 | Falha inesperada |

Os códigos de autenticação e permissão chegam no Task 9.

### VALIDACAO {#validacao}

Um ou mais campos não passaram na validação. A lista `erros` diz quais. Corrija os campos e envie de novo.

### REQUISICAO_INVALIDA {#requisicao_invalida}

A requisição não pôde ser interpretada: corpo ilegível, método não permitido (405), tipo de conteúdo não suportado (415) ou outro erro de protocolo. O `detail` descreve o problema.

### NAO_ENCONTRADO {#nao_encontrado}

O recurso não existe para o tenant do usuário. A busca sempre acontece dentro do tenant do contexto ([ADR 0037](../adr/0037-contexto-de-tenant-por-transacao.md)).

### CONFLITO {#conflito}

Já existe um registro com os mesmos dados (violação de unicidade). O texto é fixo: "Já existe um registro com os mesmos dados." A API não devolve o valor em conflito, porque ele pode ser um dado pessoal, como o e-mail.

### VERSAO_DESATUALIZADA {#versao_desatualizada}

Outra operação alterou o registro depois da leitura. Recarregue o registro e refaça a alteração.

### ERRO_INTERNO {#erro_interno}

Falha inesperada no servidor. O `detail` é fixo e não traz a causa. Informe o `traceId`: o log do servidor registra a classe da exceção com esse identificador.

## Como acrescentar um código

1. Acrescente o valor no `CodigoErro` do backend, com o status e o título.
2. Acrescente uma seção com a âncora em minúsculas nesta página (`### CODIGO {#codigo}`) e uma linha no catálogo. O `type` aponta para ela.
3. Cubra o código com um teste no `ProblemDetailsTest`.
