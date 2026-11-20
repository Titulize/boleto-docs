---
title: 'ADR 0013: Rate limiting com Bucket4j'
---

# ADR 0013: Rate limiting com Bucket4j

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Os endpoints de login, convite e "esqueci minha senha" são alvos de força bruta e de enumeração de contas.

## Decisão

Bucket4j com Valkey (via Lettuce), com limites por IP e por usuário nos endpoints de autenticação. Após falhas repetidas, a conta é bloqueada temporariamente. O AWS WAF entra depois, como camada adicional.

## Consequências

- O comportamento é o mesmo em desenvolvimento e na AWS, sem custo adicional.
- O estado do limite é compartilhado entre instâncias do backend.
- Atrás de um balanceador, o IP do cliente deve vir de um cabeçalho confiável. Isso será configurado e testado com a infraestrutura.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Só AWS WAF ou API Gateway | Só existe na AWS e tem custo |
| Limites em memória por instância | Não são compartilhados entre instâncias |
