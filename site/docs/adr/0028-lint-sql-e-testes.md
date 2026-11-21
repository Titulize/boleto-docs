---
title: 'ADR 0028: Lint de SQL com Squawk e testes em PostgreSQL real'
---

# ADR 0028: Lint de SQL com Squawk e testes em PostgreSQL real

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

A regra expand/contract ([ADR 0027](./0027-migracao-primeiro-passo.md)) só vale se algo a faz cumprir. O isolamento por tenant ([ADR 0026](./0026-roles-e-rls.md)) só está provado se for testado contra um PostgreSQL real, com a role da aplicação e sem o filtro da aplicação. O `boleto-migrations` é privado, então os minutos de CI consomem a cota gratuita. Os comandos precisam funcionar igual em Windows, Linux e CI, sem instalar nada além do Docker.

## Decisão

- **Lint com Squawk**, gratuito e de código aberto, em binário pinado no `versions.toml` (`[tools.squawk]`, com sha256). Ele bloqueia justamente o que quebra expand/contract: remover ou renomear coluna, `NOT NULL` sem valor padrão, índice sem `CONCURRENTLY` em tabela existente, entre outras regras. O `.squawk.toml` mantém todas as regras padrão ligadas. As exceções são por arquivo, com o motivo no próprio arquivo (`-- squawk-ignore-file`, ver [ADR 0030](./0030-manutencao-de-dados-e-origem-do-tenant.md)). A `V1` só cria objetos novos e tem as exceções necessárias para isso.
- **Lint dentro do Dockerfile:** o estágio `lint` baixa o Squawk, confere o sha256 e roda sobre `sql/V*.sql`. O comando é `docker build --target lint .`, igual na máquina do dev e na CI. Um arquivo com `DROP COLUMN` e `RENAME` precisa ser rejeitado, e há um teste para isso.
- **Testes em PostgreSQL real:** um `compose.test.yml` sobe PostgreSQL (mesma imagem do `versions.toml`), aplica as migrações com a imagem do Flyway e roda os casos em SQL puro (`psql -v ON_ERROR_STOP=1`) como `boleto_app`. Cada caso falha com `RAISE EXCEPTION`. Cobertura: roles sem privilégios indevidos, RLS ativo e forçado, falha fechada sem tenant, isolamento de leitura e de escrita entre os tenants A e B, funções de resolução, tenant de origem da plataforma, restrições de dados e catálogo de telas.
- **Casos negativos da imagem:** um script cobre migração alterada depois de aplicada, SQL inválido, banco inacessível, senha errada e pendência sem aplicar. Todos precisam sair com código diferente de zero. Variáveis ausentes, aspas na senha e CNPJ inválido também têm caso. O caso do lint usa fixtures com `DROP COLUMN` e renomeação.
- **CI enxuta:** dois jobs, `commitlint` (só em PR) e `banco`. Só x64. A publicação da imagem multi-arquitetura fica para o Task 14.

## Consequências

- Uma migração que quebre expand/contract não passa na CI.
- Os testes provam o isolamento com a role que o backend usa, e não com o superusuário.
- Atualizar o Squawk exige trocar versão, URL e sha256 no `versions.toml` e uma nova tag do `boleto-docs`.
- Nenhuma ferramenta nova na máquina do dev: tudo roda em container.
- Regras do Squawk podem gerar falso positivo. A exceção é por arquivo e por regra, com justificativa no próprio arquivo, revisada no PR.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| SQLFluff | Cuida de estilo e não detecta migração incompatível com a versão anterior |
| Revisão manual da regra expand/contract | Falha silenciosa. Só a revisão humana pega |
| Testar o isolamento no backend (Testcontainers) | Só rodaria depois do Task 8 e testaria o Hibernate junto. O banco precisa ser provado sozinho |
| pgTAP | Exige instalar a extensão e aprender outra sintaxe. Os testes em SQL puro bastam |
| Squawk instalado via npm | Mais uma dependência de Node na CI. O binário com sha256 é verificável |
