---
title: 'ADR 0054: CPF criptografado e blind index'
---

# ADR 0054: CPF criptografado e blind index

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

O [ADR 0015](./0015-lgpd.md) decidiu cifrar o CPF em coluna (AES-GCM) e consultar por um blind index. O Task 10 é o primeiro a gravar CPF (do usuário). O banco nunca deve ver o CPF em claro nem as chaves, e a rotação de chave precisa ser possível sem parar o sistema.

## Decisão

| Tema | Decisão |
|---|---|
| Obrigatório? | Não. O CPF é opcional no cadastro de usuário (coluna anulável; o administrador inicial não tem CPF). O DTO aceita com ou sem pontuação, valida os dígitos verificadores, recusa sequências repetidas e guarda só os 11 dígitos |
| Colunas em `usuario` | `cpf_cifrado bytea`, `cpf_indice bytea`, `cpf_chave_versao bigint` ([ADR 0056](./0056-v3-cpf-do-usuario.md)). Nada disso vai para `usuario_aud`: o CPF fica fora da auditoria (`@NotAudited`) |
| Cifra | AES-256-GCM (JCA). Nonce de 12 bytes aleatório a cada gravação. Tag de 128 bits. `cpf_cifrado = nonce(12) \|\| texto cifrado(11) \|\| tag(16)`, 39 bytes |
| AAD | `"usuario.cpf" + tenantId`. Mover o texto cifrado para outro tenant faz a decifragem falhar |
| Versão da chave | `cpf_chave_versao` guarda a versão usada. Várias versões convivem: ler usa a versão gravada, escrever usa `boleto.pii.cpf.versao-atual` |
| Blind index | `HMAC-SHA256(chaveDeIndice, tenantId + ":" + cpf11)`, 32 bytes, em `cpf_indice`. Chave separada da de cifragem. O tenant na mensagem impede correlacionar o mesmo CPF entre empresas. Único por tenant |
| Onde fica o código | Só `shared.pii` (`CifradorDeCampo`, `IndiceCego`). Uma regra do ArchUnit proíbe `javax.crypto` fora dele |
| Leitura | `UsuarioServico.cpfDe(id)` decifra e `buscarPorCpf(cpf)` usa o índice. A API devolve só `cpfMascarado` (`***.456.789-**`) |
| Conflito | CPF repetido no mesmo tenant: 409 `CONFLITO`, por verificação prévia pelo índice, com o índice único como rede de segurança |

**Chaves** ([guia](../guias/chaves-de-cpf.md)). Por variável de ambiente: `BOLETO_PII_CPF_CHAVES_1` (AES-256 em Base64, 32 bytes; `_2`, `_3` ao rotacionar), `BOLETO_PII_CPF_VERSAO_ATUAL` e `BOLETO_PII_CPF_INDICE_CHAVE` (32 bytes em Base64). Sem chaves, o backend não sobe, a não ser com `BOLETO_PII_GERAR_CHAVES_EFEMERAS=true`. As chaves efêmeras servem aos testes automatizados e nunca ao Compose: o volume do banco sobrevive ao restart e o CPF gravado ficaria ilegível.

**Chaves de desenvolvimento.** O Compose e o `application-dev.yml` usam uma constante pública e sem valor para cada chave (os bytes são o texto legível `DEV-ONLY-...`, declarada como tal nos arquivos). O backend registra WARN na subida quando reconhece a chave de dev. Nenhuma chave real entra em repositório. Em produção as chaves vêm do cofre (KMS e Secrets Manager, [ADR 0015](./0015-lgpd.md)), fora desta fase.

**Swagger.** O campo `cpf` do DTO de entrada não tem exemplo e é `writeOnly`. Nenhuma resposta tem o CPF em claro. Testes varrem `/v3/api-docs` e a saída de log.

## Consequências

- O banco, os backups e a trilha de auditoria não expõem o CPF em claro.
- **Rotação da chave de cifragem:** criar a chave nova, apontar `VERSAO_ATUAL` para ela e recifrar as linhas antigas numa tarefa futura. Até lá as duas versões convivem. O procedimento operacional entra no runbook do Task 15.
- **Troca da chave do índice** exige decifrar e recalcular todos os índices. É uma operação rara, e a chave do índice não tem versão.
- Perder a chave de cifragem torna o CPF ilegível para sempre. Backup das chaves é responsabilidade de quem opera.
- Busca por CPF parcial ou por prefixo não existe. O blind index só responde igualdade.
- O CPF em claro existe em memória durante o cadastro e a leitura. Nunca vai para log ([ADR 0055](./0055-mascara-de-dados-pessoais-nos-logs.md)).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| `pgcrypto` no banco | O banco veria o CPF e a chave |
| Hash simples (SHA-256) como índice | O espaço de CPFs é pequeno, e qualquer um que leia o banco o descobre por força bruta. O HMAC com chave separada impede |
| Índice sem o tenant na mensagem | O mesmo CPF teria o mesmo índice em empresas diferentes |
| Cifra determinística no lugar do índice | Revela quais linhas têm o mesmo CPF |
| CPF obrigatório | O administrador inicial não tem CPF, e o produto ainda não exige |
| Chave efêmera no Compose | O CPF gravado ficaria ilegível depois do restart |
