---
title: 'ADR 0011: Ambiente do desenvolvedor'
---

# ADR 0011: Ambiente do desenvolvedor

- **Status:** Aceito
- **Data:** 2026-11-20

## Contexto

O requisito mínimo é ter Docker e Docker Compose. O desenvolvimento diário precisa de Java, Gradle e Node na máquina, com as mesmas versões para todos.

## Decisão

Scripts em PowerShell (Windows) e Bash (Linux e macOS) baixam o [mise](https://mise.jdx.dev) na versão pinada, conferem o sha256 e o usam para instalar o Java 25 (Amazon Corretto) e o Node nas versões exatas do `versions.toml`. Os scripts também configuram `JAVA_HOME` e `PATH` e instalam as extensões recomendadas do Kiro e do VS Code. O Gradle vem pelo wrapper de cada projeto. O comando `doctor` diagnostica o ambiente. Dev Container não será usado.

Os repositórios de aplicação recebem um `mise.toml` gerado pela sincronização de versões, para que cada projeto selecione o Java ou o Node certos. Detalhes em [Ambiente do desenvolvedor](../guias/ambiente-do-dev.md).

Os scripts de validação e de sincronização de versões são em Node, com uma implementação para todos os sistemas.

## Consequências

- Mais rápido no dia a dia que um Dev Container, e funciona com Kiro e VS Code.
- O mise instala Java e Node em uma pasta do usuário, sem administrador e sem mexer nas versões já instaladas. O mise verifica os checksums dos downloads.
- Um único mecanismo para Java e Node nos três sistemas, em vez de winget, Homebrew e apt, cada um com suas versões.
- No Windows, o PATH da máquina vem antes do PATH do usuário. O script ativa o mise no perfil do PowerShell para corrigir isso nos terminais, e o `JAVA_HOME` do usuário vale para Gradle e IDEs.
- No Linux, a `libatomic` precisa estar instalada para o Node. Instalar exige root, então o script só avisa.
- Pode haver variação entre sistemas operacionais, mitigada pelo `doctor` e pela CI (Ubuntu e Windows PowerShell 5.1).
- Dois scripts (PowerShell e Bash) para manter.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Dev Container sobre Amazon Linux | Preferência por instalação local |
| Tudo dentro do Docker | Mais lento para editar, depurar e rodar testes |
