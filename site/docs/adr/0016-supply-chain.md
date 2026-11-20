---
title: 'ADR 0016: Cadeia de suprimentos e assinatura de imagens'
---

# ADR 0016: Cadeia de suprimentos e assinatura de imagens

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

As imagens publicadas precisam ser verificáveis: quem construiu, a partir de qual commit e com quais componentes.

## Decisão

A pipeline do GitHub Actions:

- gera um SBOM com Syft;
- escaneia vulnerabilidades com Trivy;
- publica a imagem no GHCR (ECR depois);
- assina a imagem com Cosign em modo keyless (OIDC do GitHub Actions, sem chave guardada);
- publica attestation de proveniência.

As Actions são fixadas por SHA do commit. A verificação das assinaturas no cluster fica para quando o Kubernetes entrar.

## Consequências

- Nenhuma chave de assinatura para guardar ou rotacionar.
- Todas as ferramentas são gratuitas e de código aberto.
- Aumenta o tempo da pipeline, o que consome minutos da cota gratuita.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Cosign com chave própria | Exige guardar e rotacionar a chave |
| Sem assinatura | Não há como provar a origem da imagem |
