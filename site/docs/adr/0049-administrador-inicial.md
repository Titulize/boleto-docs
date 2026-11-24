---
title: 'ADR 0049: Administrador inicial'
---
# ADR 0049: Administrador inicial
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
Não há cadastro aberto ([ADR 0012](./0012-autenticacao.md)). Um banco novo não tem nenhum usuário, então alguém precisa entrar para criar os demais.
## Decisão
- As variáveis `BOLETO_ADMIN_INICIAL_EMAIL` e `BOLETO_ADMIN_INICIAL_SENHA` definem o primeiro administrador. A senha tem no mínimo 12 caracteres; com menos, o backend não sobe.
- Um `ApplicationRunner` no módulo `auth` cria, se o e-mail não existir, um usuário `ATIVO` na empresa gestora Titulize (`00000000-0000-7000-8000-000000000001`), com o perfil `Administrador da plataforma` (`00000000-0000-7000-8000-000000000101`, semeado na V1).
- É idempotente: se o e-mail já existe, não altera senha, situação nem perfil.
- Variáveis vazias significam que nada é criado.
- A senha nunca aparece em log.
- A auditoria grava o usuário de sistema `00000000-0000-7000-8000-0000000000ff` em `revinfo.usuario_id`.
- O Compose de desenvolvimento tem valores padrão (`admin@boleto.test` e uma senha de dev). Fora do desenvolvimento não há padrão.
## Consequências
- Em produção a senha inicial vem de um cofre de segredos e deve ser trocada depois do primeiro acesso, quando o fluxo de convite e de troca de senha existir.
- Mudar a variável depois da criação não muda a senha do administrador.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| Usuário e senha fixos em migração | A senha ficaria no git e igual em todos os ambientes |
| Senha aleatória gravada no log | Segredo no log |
| Endpoint de cadastro do primeiro usuário | Rota pública que precisaria de proteção própria |
