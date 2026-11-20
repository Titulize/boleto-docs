---
title: 'ADR 0004: Frontend com Angular e Angular Material'
---

# ADR 0004: Frontend com Angular e Angular Material

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O painel tem muitos CRUDs, formulários e controle de acesso por perfil. O desenvolvedor conhece React, mas aceita aprender Angular.

## Decisão

Angular 22 com standalone components, rotas com lazy loading e Angular Material como design system. O cliente da API é gerado a partir do OpenAPI do backend.

## Consequências

- Formulários, rotas, injeção de dependência e HTTP já vêm integrados.
- O Angular Material segue o Material Design e é mantido junto com o Angular.
- Curva de aprendizado inicial maior que a do React.
- O Angular 22 exige TypeScript 6.0.x e Node 22.22.3, 24.15 ou 26.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| React com Vite | Exige escolher e integrar bibliotecas de rotas, formulários e estado |
| Materialize CSS | O projeto original está parado desde 2018 |
