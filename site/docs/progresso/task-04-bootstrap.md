---
sidebar_position: 4
title: 'Task 04: Bootstrap do ambiente'
---

# Task 04: Scripts de bootstrap do ambiente do dev

- **Situação:** Em andamento
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-20
- **Repositórios:** `boleto-docs`

## Objetivo

Configurar a máquina do desenvolvedor com um comando, exigindo só Docker, Compose e Git.

## Entregue

- `bootstrap/bootstrap.ps1` (Windows) e `bootstrap/bootstrap.sh` (Linux e macOS), com os comandos `install` e `doctor`.
- O script baixa o mise na versão pinada e confere o sha256. O mise instala o Corretto 25.0.5.1.2 e o Node 26.13.1. O Gradle vem pelo wrapper.
- Configuração do `JAVA_HOME` e do `PATH` do usuário, ativação do mise no perfil do PowerShell e bloco nos arquivos do shell (`.bashrc`, `.profile`, `.bash_profile`, `.zshrc`).
- Extensões do Kiro e do VS Code em `bootstrap/extensions.txt`.
- Opção `-InstallDir` / `--install-dir`: instala tudo em uma pasta do usuário, com a escolha gravada em `BOLETO_INSTALL_DIR`. Nenhum passo exige administrador.
- A sincronização passou a gerar `mise.toml` e as variáveis do mise. Tag `v0.3.0`.
- Guia [Ambiente do desenvolvedor](../guias/ambiente-do-dev.md) e [ADR 0011](../adr/0011-ambiente-do-dev.md) atualizados.

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| Windows, pwsh 7 | `install`, `doctor` e segunda execução em pasta isolada | passou, idempotente |
| Windows, `-InstallDir` | `install -NoPersist` em pasta com espaço, e casos de erro (caminho relativo, `;`, `Program Files`) | passou, ambiente do usuário intacto |
| Amazon Linux 2023 limpo | `install` como root e como usuário comum sem `sudo`, shell novo, troca de pasta | passou |
| CI, Ubuntu | ShellCheck, `install` e `doctor` isolados, `install --install-dir` persistente e shell de login novo | verde no commit `90405d3` |
| CI, Windows PowerShell 5.1 | `install` e `doctor` isolados, `install -InstallDir` persistente, terminal novo, troca de pasta | verde no commit `90405d3` |

Não verificado: macOS, e o `install` real (persistente) na máquina de um desenvolvedor.

## Falhas e correções

- **CI falhou no commit `284e26c`.** O ShellCheck reclamou de aspas simples intencionais, e o Windows PowerShell 5.1 trata o `stderr` de programas nativos como erro fatal com `ErrorActionPreference = 'Stop'`. Corrigido em `901c35c`. Causa: o envio foi feito sem rodar o ShellCheck e o PowerShell 5.1 localmente.
- **CI falhou no commit `f48d124`.** O ShellCheck reclamou de padrões do `case`. Corrigido em `90405d3`. Mesma causa.
- Em testes locais: o Node precisa da `libatomic` no Linux (o script passou a verificar antes de baixar) e, na troca de pasta, o script reaproveitava o mise da pasta antiga (passou a instalar sempre na pasta escolhida).

Para evitar a repetição, o [padrão do projeto](../guias/padrao-do-projeto.md) passou a exigir a verificação local e o trabalho em branch com PR.

## Decisões e desvios do plano

- O mise substituiu o winget: funciona igual nos três sistemas, fixa a versão exata e não precisa de administrador.

## Pendências

- Rodar o `install` real na máquina do Danilo e confirmar o `doctor` verde (aguardando autorização e a pasta escolhida).

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Scripts, CI no Ubuntu e no Windows PowerShell 5.1, tag `v0.3.0` |
| 2026-11-20 | Opção `-InstallDir` / `--install-dir` |
| 2026-11-20 | Registro criado junto com o padrão do projeto |
