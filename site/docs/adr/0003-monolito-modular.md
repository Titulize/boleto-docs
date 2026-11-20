---
title: 'ADR 0003: Monólito modular por funcionalidade'
---

# ADR 0003: Monólito modular por funcionalidade

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

Os módulos de negócio (auth, usuários, empresas, títulos, faturas, carteira, CNAB) crescem juntos e compartilham transações. Microserviços agora trariam custo operacional sem benefício.

## Decisão

Um único backend organizado por funcionalidade, com Spring Modulith e ArchUnit para verificar os limites entre módulos. Módulos complexos (CNAB e faturas) usam hexagonal leve, com o domínio isolado de framework e banco.

## Consequências

- Deploy simples e transações locais.
- Dependências proibidas entre módulos falham no build.
- Um módulo pode virar serviço separado depois, porque a API pública já está definida.
- Exige disciplina para manter as APIs de módulo pequenas.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Camadas clássicas (controller, service, repository) | O acoplamento cresce e as regras se espalham |
| Hexagonal completa em tudo | Mais código e cerimônia do que os módulos simples precisam |
| Microserviços | Custo operacional e de infraestrutura sem necessidade atual |
