---
title: 'ADR 0045: Claims, tempos de vida e sessão diária'
---
# ADR 0045: Claims, tempos de vida e sessão diária
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O token precisa identificar usuário, tenant e sessão sem carregar dados pessoais. A sessão de trabalho deve acabar no fim do dia, e as permissões não podem ficar velhas dentro de um token já emitido.
## Decisão
- Claims só com referências: `sub` (usuário), `tid` (tenant efetivo), `tor` (tenant de origem), `sid` (sessão), `jti`, `iss`, `aud`, `iat`, `nbf` e `exp`. O token não leva e-mail, nome nem permissões.
- As permissões são lidas do banco a cada requisição. Bloqueio de usuário e troca de perfil valem na hora, sem esperar o token expirar.
- **Access token: 1 hora.**
- **Sessão diária:** a sessão acaba na próxima meia-noite do fuso `America/Sao_Paulo` (propriedade `boleto.seguranca.fuso`). `sessaoExpiraEm` é a primeira 00:00 depois do login. O `exp` do access é `min(emissão + 1 h, sessaoExpiraEm)`.
- **Refresh token: 8 horas**, limitado a `sessaoExpiraEm`. O refresh nunca estende a sessão: depois da meia-noite ele falha e a pessoa precisa fazer login.
- Cada refresh emite um novo access de 1 hora, respeitando o limite da sessão.
- O backend usa um `Clock` injetável (bean em `shared`), para que os testes controlem o horário.
- **Suposição a confirmar:** o fuso `America/Sao_Paulo` foi escolhido sem confirmação do usuário do produto. Mudar o fuso é só trocar a propriedade.

## Consequências
- Roubo de um access token vale no máximo 1 hora, e a sessão inteira no máximo até a meia-noite.
- Quem trabalha na virada do dia é desconectado e refaz o login.
- Uma consulta de permissões por requisição custa uma ida ao banco. Se virar gargalo, um cache curto pode entrar depois, em novo ADR.
- **Nota (2026-11-24), fuso confirmado:** o usuário do produto confirmou que o fuso deve ser o do local de onde a pessoa se loga e que, por ora, a plataforma atua só no Brasil. A decisão não muda: continua `America/Sao_Paulo`, único e configurável (`boleto.seguranca.fuso`). A evolução prevista é usar o fuso do usuário logado, o que exige decidir de onde ele vem (cadastro do usuário, da empresa ou do navegador) e como a meia-noite da sessão se comporta ao mudar de fuso. Isso pede novo ADR quando houver operação fora do Brasil. A pendência está no [registro do Task 9](../progresso/task-09-autenticacao-autorizacao.md).
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Permissões dentro do token | Ficam velhas até o token expirar; o token cresce |
| Sessão deslizante, sem limite diário | Sessão roubada poderia durar indefinidamente |
| Fuso UTC | A meia-noite UTC cai às 21:00 em Brasília e cortaria o expediente |
