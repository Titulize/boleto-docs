---
title: 'ADR 0031: Primeira main do boleto-backend por exceção'
---
# ADR 0031: Primeira `main` do `boleto-backend` por exceção
- **Status:** Aceito
- **Data:** 2026-11-21
## Contexto
O [padrão do projeto](../guias/padrao-do-projeto.md) proíbe commit direto na `main`. O repositório `boleto-backend` foi criado vazio, sem nenhum commit, e um PR precisa de uma branch base que exista. É o mesmo caso do [ADR 0023](./0023-primeira-main-boleto-migrations.md), que tratou só do `boleto-migrations` e limitou a exceção "ao repositório vazio" daquele registro.
## Decisão
- **Exceção única, autorizada pelo usuário na conversa do Task 7:** o primeiro commit do `boleto-backend` vai direto para a `main`. É o commit `d7833fe`, com a mensagem `chore: inicia repositório`. Ele contém só `.gitignore` e `.gitattributes`.
- **Sem código nem workflow:** não há o que revisar nem o que a CI verificar.
- **Depois dele, a regra normal:** todo o resto entra por branch e PR, com squash e workflows verdes. O esqueleto do backend entrou assim (PR [#1](https://github.com/Titulize/boleto-backend/pull/1), squash `b3e8eb5`).
- **Escopo:** vale só para a primeira `main` de um repositório vazio. A decisão do ADR 0023 não muda; este ADR registra a segunda aplicação da mesma exceção.
## Consequências
- O primeiro PR do `boleto-backend` tem base para comparar.
- O hash do commit inicial fica registrado, para que a exceção não vire hábito.
- O [padrão do projeto](../guias/padrao-do-projeto.md) aponta para os dois ADRs. O `boleto-frontend`, quando for criado vazio, precisará do mesmo registro (um ADR novo).
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Estender o ADR 0023 | O ADR 0023 é aceito, trata do `boleto-migrations` e vale só para ele. Um ADR por repositório mantém cada exceção datada e com o seu hash |
| Commit inicial por PR | O GitHub não abre PR sem uma branch base com histórico em comum |
| Criar o repositório com README pelo GitHub | O arquivo nasceria fora do padrão (sem commitlint) e seria reescrito no primeiro PR |