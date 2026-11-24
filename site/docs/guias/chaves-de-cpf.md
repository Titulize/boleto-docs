---
sidebar_position: 7
title: Chaves de CPF
---

# Chaves do CPF cifrado

O CPF do usuário é cifrado pelo backend com AES-256-GCM e consultado por um blind index HMAC-SHA256 ([ADR 0054](../adr/0054-cpf-criptografado-e-blind-index.md)). Duas chaves de 32 bytes fazem isso: a de cifragem (com versão) e a do índice. Este guia diz de onde elas vêm, como gerar uma nova e como rotacionar.

## Variáveis

| Variável | Para que serve |
|---|---|
| `BOLETO_PII_CPF_CHAVES_1` | Chave de cifragem da versão 1: 32 bytes em Base64. Ao rotacionar, acrescente `_2`, `_3` e assim por diante |
| `BOLETO_PII_CPF_VERSAO_ATUAL` | Versão que cifra as gravações novas (`1`). Precisa ter a chave correspondente |
| `BOLETO_PII_CPF_INDICE_CHAVE` | Chave do blind index: 32 bytes em Base64. Sem versão |
| `BOLETO_PII_GERAR_CHAVES_EFEMERAS` | `true` gera chaves a cada início. Só para testes automatizados |

Sem chaves e sem `BOLETO_PII_GERAR_CHAVES_EFEMERAS=true`, o backend não sobe e diz qual variável falta. Uma chave que não decodifica para 32 bytes também impede a subida.

## Gerar uma chave

```bash
openssl rand -base64 32
```

Gere uma chave diferente para cada versão de cifragem e outra para o índice. No Windows sem OpenSSL, use o Git Bash ou o PowerShell:

```powershell
$b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
```

## Chaves de desenvolvimento

O Compose e o `application-dev.yml` trazem duas chaves **públicas e sem valor**: os 32 bytes são texto legível que começa com `DEV-ONLY-`. Elas existem para o CPF gravado sobreviver ao restart do backend. O backend registra um WARN ao reconhecê-las. Um teste do `boleto-docs` (`npm test`) exige que as chaves do Compose sejam essas constantes e recusa qualquer outra.

## O que não fazer

- Nunca colocar uma chave real no `docker-compose.yml`, no `.env.example`, em `application*.yml`, em README, em issue ou em log. O `boleto-docs` é público.
- Nunca usar as chaves de dev fora do desenvolvimento.
- Nunca usar chaves efêmeras no Compose. O volume do banco sobrevive ao restart, e o CPF gravado ficaria ilegível para sempre.
- Nunca reaproveitar a chave de cifragem como chave do índice.
- Nunca apagar uma versão de chave enquanto houver linhas com `cpf_chave_versao` igual a ela.

## Rotação da chave de cifragem

1. Gere a chave nova e publique-a como `BOLETO_PII_CPF_CHAVES_2`, mantendo a `_1`.
2. Aponte `BOLETO_PII_CPF_VERSAO_ATUAL` para `2` e reinicie o backend. As gravações novas usam a versão 2. As linhas antigas continuam legíveis, pela versão guardada em `cpf_chave_versao`.
3. Recifre as linhas antigas (decifrar com a versão 1 e gravar com a 2). Essa tarefa ainda não existe e entra no runbook do Task 15.
4. Só depois de `select count(*) from boleto.usuario where cpf_chave_versao = 1` devolver 0, retire a chave `_1`.

## Troca da chave do índice

A chave do índice não tem versão. Trocá-la exige decifrar o CPF de todas as linhas e recalcular `cpf_indice`. É uma operação rara, para a qual ainda não há rotina. Planeje uma janela e um backup antes.

## Produção

Em produção as chaves vêm do cofre (KMS e Secrets Manager, [ADR 0015](../adr/0015-lgpd.md)) e chegam ao backend por variável de ambiente. Isso está fora da Fase 1. Faça backup das chaves em local separado do banco: sem a chave, o CPF cifrado não se recupera.
