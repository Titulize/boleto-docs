---
title: 'ADR 0007: Auditoria com Hibernate Envers'
---

# ADR 0007: Auditoria com Hibernate Envers

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O sistema precisa registrar quem alterou um dado na tela, o valor anterior, o novo valor, a data e a hora. A ideia inicial era usar um banco NoSQL para isso.

## Decisão

Hibernate Envers no PostgreSQL, com entidade de revisão customizada (usuário, tenant, data e hora). O NoSQL fica fora da Fase 1 e pode voltar atrás de uma interface, se aparecer necessidade real.

## Consequências

- A auditoria entra na mesma transação da alteração e nunca fica inconsistente com ela.
- Não há banco, SDK nem emulador a mais para manter, e o desenvolvimento continua a custo zero.
- A tabela de auditoria cresce junto com o banco principal. Particionamento ou arquivamento entram quando necessário.
- O diff mostrado na tela é calculado comparando revisões.
- O usuário da revisão vem do JWT da requisição.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| MongoDB | Custo fixo na AWS (DocumentDB ou Atlas) sem necessidade de busca livre |
| DynamoDB e S3 | Baixo custo, mas exige emulador local, outro SDK e tratamento de consistência entre dois bancos (padrão outbox) |
