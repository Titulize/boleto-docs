---
title: 'ADR 0010: Imagens Amazon Linux 2023 pinadas por digest'
---

# ADR 0010: Imagens Amazon Linux 2023 pinadas por digest

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O destino futuro é a AWS. Imagens com o mesmo sistema operacional em desenvolvimento e produção reduzem diferenças de comportamento.

## Decisão

Backend, frontend, migrações e documentação usam imagens baseadas em Amazon Linux 2023, com tag e digest. O backend usa o Amazon Corretto 25 (`25.0.5-al2023`). As imagens são puxadas do ECR Público (`public.ecr.aws`) para evitar o limite de pulls do Docker Hub.

PostgreSQL, Valkey, Mailpit e Grafana LGTM usam as imagens oficiais, também com digest. Em produção, PostgreSQL e Valkey são serviços gerenciados.

## Consequências

- Atualizações de segurança do sistema operacional exigem trocar o digest, o que o Renovate propõe.
- O Flyway CLI só tem build linux-x64. Em máquinas ARM roda por emulação. (Descoberta posterior: a imagem de migração passou a usar os JARs do Flyway sobre o Corretto headless, que roda em x64 e ARM. Ver [ADR 0024](./0024-flyway-jar-corretto.md).)
- Imagens oficiais de banco não são Amazon Linux, o que é aceitável porque em produção serão serviços gerenciados.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Imagens Debian ou Alpine | Diferem do sistema operacional da AWS |
| Tags sem digest | A mesma tag pode apontar para conteúdo diferente com o tempo |
