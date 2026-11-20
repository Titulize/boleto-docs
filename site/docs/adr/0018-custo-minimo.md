---
title: 'ADR 0018: Custo mínimo e repositório de documentação público'
---

# ADR 0018: Custo mínimo e repositório de documentação público

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O projeto exige o menor custo possível, com desenvolvimento a custo zero. Os repositórios foram criados como privados na organização gratuita do GitHub. Nesse plano, o GitHub Pages e a branch protection não funcionam em repositório privado.

## Decisão

- Só ferramentas gratuitas e de código aberto em desenvolvimento.
- Nenhum serviço pago de nuvem na Fase 1.
- O `boleto-docs` é público, para habilitar GitHub Pages e branch protection. Os outros três continuam privados.
- Para a AWS, a escolha segue o menor custo (ver [Custos](../guias/custos.md)).

## Consequências

- O `versions.toml` e a documentação ficam visíveis a qualquer pessoa. Eles não devem conter segredos, nomes de clientes nem dados internos.
- A CI dos repositórios privados usa a cota mensal gratuita de minutos.
- Branch protection nos repositórios privados exige plano pago e fica como convenção documentada.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Tudo privado, documentação só local | Sem site compartilhável |
| Publicar em outro serviço gratuito | Uma conta e uma configuração a mais sem necessidade |
