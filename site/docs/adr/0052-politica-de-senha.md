---
title: 'ADR 0052: Política de senha'
---

# ADR 0052: Política de senha

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

Até o Task 9 a única regra era o tamanho mínimo de 12 caracteres, aplicado ao administrador inicial ([ADR 0049](./0049-administrador-inicial.md)). O Task 10 deixa o usuário escolher a própria senha por um endpoint público, então a regra precisa ser explícita e testada.

## Decisão

A classe `usuarios.PoliticaDeSenha` aplica estas regras em `POST /auth/definir-senha` e no administrador inicial. Seguem a recomendação do NIST SP 800-63B (tamanho e lista de senhas comuns, sem exigir classes de caracteres):

| Regra | Detalhe |
|---|---|
| Tamanho | De 12 a 128 caracteres. Conta pontos de código, aceita espaços e Unicode. O máximo evita custo de Argon2 com entrada enorme |
| Diversidade | Pelo menos 6 caracteres diferentes (recusa `aaaaaaaaaaaa`) |
| Sequência simples | Recusa a senha inteira em passos de +1 ou -1 (`123456789012`, `abcdefghijkl`). Dígitos e letras dão a volta (9 para 0, z para a) |
| Senhas comuns | Lista embutida em `src/main/resources/seguranca/senhas-comuns.txt`, escrita para o projeto. Compara sem diferenciar maiúsculas nem acentos. Sem dependência nova |
| Contexto | Só em `definir-senha`: a senha não pode conter a parte local do e-mail nem o nome completo do usuário (sem diferenciar maiúsculas e acentos), quando essa parte tem 4 caracteres ou mais |

- Não há exigência de maiúscula, número ou símbolo.
- A violação responde 400 `SENHA_FRACA`, com a regra violada em português. A mensagem nunca traz a senha.
- Violação não consome o token: a validação e o consumo ficam na mesma transação.
- **Administrador inicial:** a política vale, sem a regra de contexto (a senha vem de variável de ambiente do operador). A senha de dev do Compose passa nela, e um teste garante isso. Se a senha não passar, o backend falha na subida, como já falhava com o tamanho. `AdminInicial.SENHA_MINIMA` aponta para `PoliticaDeSenha.TAMANHO_MINIMO`.
- A política vale só para senha nova. Senhas já gravadas não são revalidadas.

## Consequências

- A lista de senhas comuns é pequena e cobre só as de 12 caracteres ou mais. Ela não substitui uma consulta a bases de vazamentos. Crescer a lista é editar o arquivo.
- Sem classes de caracteres, uma frase longa em português passa. É o efeito desejado.
- Trocar uma regra exige novo ADR ou nota, porque o frontend precisa mostrar o mesmo texto.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Exigir maiúscula, número e símbolo | O NIST desaconselha: gera senhas previsíveis como `Senha@2026` |
| Biblioteca de força de senha (zxcvbn) | Dependência nova para um ganho pequeno neste ponto |
| Consultar uma API de vazamentos | Envia dados a terceiro e depende de rede |
| Mínimo de 8 caracteres | O mínimo de 12 já estava em vigor no administrador inicial |
