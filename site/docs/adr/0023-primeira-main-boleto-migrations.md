---
title: 'ADR 0023: Primeira main do boleto-migrations por exceção'
---

# ADR 0023: Primeira `main` do `boleto-migrations` por exceção

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O [padrão do projeto](../guias/padrao-do-projeto.md) proíbe commit direto na `main`: todo trabalho vai por branch e PR. O repositório `boleto-migrations` foi criado vazio, sem nenhum commit. Um PR precisa de uma branch base que exista, então o primeiro PR não pode ser aberto contra uma `main` inexistente.

## Decisão

- **Exceção única:** o primeiro commit do `boleto-migrations` vai direto para a `main`, com a mensagem `chore: inicia repositório`. Ele contém só `.gitignore` e `.gitattributes`.
- **Sem código nem workflow:** o commit não tem código, SQL nem arquivo de CI. Não há o que revisar nem o que a CI verificar.
- **Depois dele, a regra normal:** todo o resto entra por branch e PR, com squash e workflows verdes.
- **Registro:** o hash do commit inicial fica no [registro de progresso do Task 6](../progresso/task-06-boleto-migrations.md).
- **Escopo:** a exceção vale para a primeira `main` de um repositório vazio. Não vale para nenhum outro commit nem para outro repositório que já tenha `main`.

## Consequências

- O primeiro PR do `boleto-migrations` tem uma base para comparar.
- A exceção fica escrita e datada. Sem o registro, um push direto vira hábito.
- O [padrão do projeto](../guias/padrao-do-projeto.md) cita a exceção, para que quem criar um repositório novo saiba o que fazer.
- A proteção da `main` (PR obrigatório) é ligada depois do commit inicial.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Commit inicial por PR | O GitHub não abre PR sem uma branch base com histórico em comum |
| Criar o repositório já com README pelo GitHub | O arquivo nasceria fora do padrão do projeto (sem revisão, sem commitlint) e traria conteúdo que será reescrito no primeiro PR |
| Branch `main` órfã criada por PR de outra branch | Dá o mesmo resultado com mais passos e sem revisão do que não há para revisar |
