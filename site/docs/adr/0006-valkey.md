---
title: 'ADR 0006: Valkey para cache, sessão e rate limit'
---

# ADR 0006: Valkey para cache, sessão e rate limit

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O backend precisa de um armazenamento em memória para refresh tokens, blacklist de logout, contadores de rate limit e cache. A AWS oferece ElastiCache com Redis OSS e com Valkey.

## Decisão

Valkey 9.1 no lugar do Redis. O protocolo é compatível, então o cliente Lettuce do Spring e o Bucket4j funcionam sem mudança de código. Na AWS: ElastiCache for Valkey.

## Consequências

- Menor custo na AWS (a AWS indica preço menor que o do Redis OSS).
- Licença de código aberto (BSD), sem a incerteza de licença do Redis.
- A versão 9.1 é a linha oferecida pelo ElastiCache. A 9.2 já existe e será adotada quando a AWS a oferecer.
- A imagem local é `valkey/valkey` do Docker Hub, sujeita ao limite de pulls anônimos.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Redis 8 | O ElastiCache pode não acompanhar a versão, e o custo é maior |
| Cache só em memória da aplicação | Não funciona com mais de uma instância e perde o estado ao reiniciar |
