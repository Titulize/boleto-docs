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
| [`NAO_AUTENTICADO`](#nao_autenticado) | 401 | Sem token Bearer válido |
| [`CREDENCIAIS_INVALIDAS`](#credenciais_invalidas) | 401 | Login recusado |
| [`TOKEN_INVALIDO`](#token_invalido) | 401 | Token expirado, adulterado ou de sessão revogada |
| [`REFRESH_REUTILIZADO`](#refresh_reutilizado) | 401 | Refresh token já usado; a sessão foi revogada |
| [`SEM_PERMISSAO`](#sem_permissao) | 403 | Usuário autenticado sem a permissão da rota |
| [`LIMITE_EXCEDIDO`](#limite_excedido) | 429 | Limite de requisições ou bloqueio por tentativas de login |
| [`SERVIDOR_INDISPONIVEL`](#servidor_indisponivel) | 503 | Dependência necessária fora do ar (Valkey) |
| [`ERRO_INTERNO`](#erro_interno) | 500 | Falha inesperada |

Os sete códigos de autenticação e permissão vêm do Task 9 ([Autenticação e autorização](./autenticacao.md)).

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

### NAO_AUTENTICADO {#nao_autenticado}

A requisição não trouxe um token Bearer válido. Faça login ou renove o token.

### CREDENCIAIS_INVALIDAS {#credenciais_invalidas}

E-mail ou senha incorretos. A resposta é a mesma para e-mail inexistente, senha errada e usuário inativo ou bloqueado, para não revelar quais e-mails existem.

### TOKEN_INVALIDO {#token_invalido}

O token expirou, foi adulterado, tem emissor ou audiência errados, ou pertence a uma sessão revogada (logout, reuso de refresh ou fim da sessão diária). Renove com o refresh ou faça login.

### REFRESH_REUTILIZADO {#refresh_reutilizado}

O refresh token já tinha sido usado. O backend entende como possível roubo e revoga a sessão inteira. Faça login de novo.

### SEM_PERMISSAO {#sem_permissao}

O usuário está autenticado, mas seus perfis não dão a ação na tela que a rota exige.

### LIMITE_EXCEDIDO {#limite_excedido}

Limite por IP ou por e-mail excedido, ou conta bloqueada por 5 senhas erradas. O cabeçalho `Retry-After` diz quantos segundos esperar.

### SERVIDOR_INDISPONIVEL {#servidor_indisponivel}

O Valkey, necessário para validar a sessão, está inacessível. O backend recusa a requisição em vez de aceitar um token sem conferir. Tente de novo em instantes.

## Como acrescentar um código

1. Acrescente o valor no `CodigoErro` do backend, com o status e o título.
2. Acrescente uma seção com a âncora em minúsculas nesta página (`### CODIGO {#codigo}`) e uma linha no catálogo. O `type` aponta para ela.
3. Cubra o código com um teste no `ProblemDetailsTest`.
