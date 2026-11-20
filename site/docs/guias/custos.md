---
sidebar_position: 2
title: Custos
---

# Custos

Restrição do projeto: custo mínimo. Desenvolvimento a custo zero.

## Desenvolvimento

| Item | Custo | Observação |
|---|---|---|
| Docker, PostgreSQL, Valkey, Mailpit, Grafana LGTM | zero | Código aberto, rodam local |
| GitHub (organização gratuita) | zero | Repositórios privados têm cota mensal de minutos do Actions |
| GitHub Pages | zero | Só funciona em repositório público, por isso o `boleto-docs` é público |
| GHCR (imagens) | zero | Dentro dos limites do plano gratuito |
| Cosign keyless, Trivy, Syft, Renovate | zero | Código aberto |

## Limites do plano gratuito do GitHub

- Os repositórios `boleto-backend`, `boleto-frontend` e `boleto-migrations` são privados. A CI deles consome a cota mensal gratuita de minutos da organização.
- Branch protection em repositório privado exige plano pago. No `boleto-docs` (público) ela está disponível.
- Se a cota acabar, a opção é tornar os repositórios públicos ou reduzir o uso da CI (cache, filtros por caminho).

## AWS (futuro)

Nada da AWS é contratado nesta fase. Ao planejar a AWS, a ordem de preferência é a de menor custo: Aurora Serverless v2 ou RDS pequeno para o PostgreSQL, ElastiCache for Valkey (mais barato que Redis OSS), SES para e-mails e ECR para imagens.
