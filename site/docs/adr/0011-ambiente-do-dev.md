---
title: 'ADR 0011: Ambiente do desenvolvedor'
---

# ADR 0011: Ambiente do desenvolvedor

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O requisito mínimo é ter Docker e Docker Compose. O desenvolvimento diário precisa de Java, Gradle e Node na máquina, com as mesmas versões para todos.

## Decisão

Scripts em PowerShell (Windows) e Bash (Linux e macOS) instalam Java 25 (Corretto), Node e as extensões recomendadas do Kiro e do VS Code, lendo as versões do `versions.toml`. O Gradle vem pelo wrapper de cada projeto. O comando `doctor` diagnostica o ambiente. Dev Container não será usado.

Os scripts de validação e de sincronização de versões são em Node, com uma implementação para todos os sistemas.

## Consequências

- Mais rápido no dia a dia que um Dev Container, e funciona com Kiro e VS Code.
- Pode haver variação entre sistemas operacionais, mitigada pelo `doctor` e pela CI.
- Dois conjuntos de scripts (PowerShell e Bash) para manter.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Dev Container sobre Amazon Linux | Preferência por instalação local |
| Tudo dentro do Docker | Mais lento para editar, depurar e rodar testes |
