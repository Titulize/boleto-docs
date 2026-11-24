---
title: 'ADR 0055: Máscara de dados pessoais nos logs'
---

# ADR 0055: Máscara de dados pessoais nos logs

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto

O [ADR 0015](./0015-lgpd.md) proíbe dados pessoais em log. Até o Task 9, só existia a `MascaraDeEmail`, privada ao módulo `auth`. O Task 10 passa a lidar com nome, e-mail, CPF, senha e token no mesmo fluxo, e os logs são JSON com `traceId` ([ADR 0041](./0041-logs-json-com-traceid.md)).

## Decisão

A classe pública `shared.log.MascaraDeDados` oferece:

| Método | Formato | Exemplo |
|---|---|---|
| `email` | primeira letra, `***` e o domínio | `a***@dominio` |
| `cpf` | `***.` mais os dígitos 4 a 6, `.`, os dígitos 7 a 9 e `-**` | `***.456.789-**` |
| `nome` | primeira letra de cada palavra seguida de `***` | `A*** S***` |
| `nulo` | `?` | `?` |

O CPF mascarado mostra os dígitos de posição 4 a 9 (`***.456.789-**`), com ou sem pontuação na entrada. Se a entrada não tem 11 dígitos, devolve `***`. A `auth.MascaraDeEmail` passa a delegar para a nova classe, então os chamadores atuais não mudam.

**Regra.** E-mail, CPF, nome, senha, token, hash de senha e chave nunca entram em log em claro. Quando for preciso identificar alguém, usa-se o id do usuário ou a versão mascarada. Mensagens de exceção do JavaMail, do driver e do Hibernate não vão para log (só o nome da classe), porque podem trazer o endereço ou o valor em conflito. O log do `Detail` do PostgreSQL já estava desligado ([ADR 0015](./0015-lgpd.md)).

**Testes.** `MascaraDeDadosTest` cobre os formatos. `LogsConviteIT` percorre o fluxo inteiro (convite, definir senha, esqueci, redefinir) e confere que a saída não tem token, senha, e-mail, CPF (com e sem pontuação), nome completo nem hash, e que as versões mascaradas aparecem. O `toString` de `Usuario`, `TokenDeUsuarioEmitido` e dos DTOs de entrada não mostra dado pessoal.

**Lacuna registrada.** Não há filtro de saída que apague dados pessoais de qualquer linha de log. A API de customização do formato JSON estruturado do Spring Boot 4.1 não foi verificada neste task. A defesa é a máscara explícita mais os testes que varrem a saída.

## Consequências

- Quem escreve um `LOG.info` novo precisa lembrar de mascarar. O teste do fluxo de senha pega o esquecimento só nesse fluxo.
- Um filtro de saída (rede de proteção) fica como melhoria, quando a API do log estruturado for verificada.
- A máscara de e-mail mostra a primeira letra e o domínio, o que ainda identifica empresas pequenas. É um compromisso aceito para o diagnóstico.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Não logar nada que tenha dado pessoal | O suporte perde a pista de quem falhou. O id do usuário serve, mas nem sempre existe (e-mail desconhecido) |
| Filtro de saída agora | A API do formato JSON do Spring Boot 4.1 não foi verificada. Um filtro mal feito dá falsa sensação de segurança |
| Hash do e-mail no log | Não deixa o suporte reconhecer o e-mail, e o hash sem sal é fraco |
