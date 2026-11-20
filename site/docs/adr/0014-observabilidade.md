---
title: 'ADR 0014: Observabilidade com OpenTelemetry'
---

# ADR 0014: Observabilidade com OpenTelemetry

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

É preciso diagnosticar problemas desde o início, em desenvolvimento e na AWS, sem custo extra local.

## Decisão

Actuator, Micrometer e OpenTelemetry no backend, com logs em JSON e `traceId` em cada linha. Em desenvolvimento, um profile opcional do Compose sobe o `grafana/otel-lgtm` (Grafana, Loki, Tempo e Prometheus). Na AWS, os dados seguem para CloudWatch e X-Ray.

## Consequências

- Os mesmos sinais em desenvolvimento e produção.
- O profile `observability` consome memória, então é opcional.
- Logs nunca contêm dados pessoais sem máscara (ver [ADR 0015](./0015-lgpd.md)).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Só logs de texto | Sem correlação entre requisições |
| Datadog ou New Relic | Custo |
