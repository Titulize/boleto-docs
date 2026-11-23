---
title: 'ADR 0044: JWT com ES256 e origem da chave'
---
# ADR 0044: JWT com ES256 e origem da chave
- **Status:** Aceito
- **Data:** 2026-11-23
## Contexto
O [ADR 0012](./0012-autenticacao.md) escolheu JWT de acesso de vida curta, mas não fixou o algoritmo nem de onde vem a chave de assinatura. O Task 9 precisa dos dois para emitir e validar tokens.
## Decisão
- Algoritmo **ES256** (ECDSA com P-256), com o Nimbus JOSE que acompanha o `spring-security-oauth2-jose`.
- A chave privada vem da variável `BOLETO_JWT_CHAVE_PRIVADA`: PEM PKCS#8 codificado em base64, em uma linha. A chave pública é derivada dela.
- Sem a chave e sem `BOLETO_JWT_GERAR_CHAVE_EFEMERA=true`, o backend não sobe. A chave efêmera existe só no desenvolvimento: o Compose liga a flag, o backend registra um aviso (WARN) e os tokens deixam de valer a cada reinício.
- Nenhuma chave vai para o git. Na AWS, a mesma variável será preenchida pelo Secrets Manager (fase de infraestrutura).
- O cabeçalho do token leva `kid`, para permitir rotação de chave no futuro.
- A validação exige `iss`, `aud=boleto-api`, `exp` e `nbf`. Tokens com `alg=none` ou com outro algoritmo são recusados.
## Consequências
- Chave assimétrica: outro serviço pode validar tokens só com a chave pública, sem poder emitir.
- Com a chave efêmera, quem usa o Compose precisa fazer login de novo depois de reiniciar o backend.
- Rotação de chave exige trabalho adicional (publicar mais de uma chave pública); o `kid` deixa o caminho aberto.
## Alternativas consideradas
| Alternativa | Por que não |
|---|---|
| HS256 (segredo compartilhado) | Quem valida também poderia emitir tokens |
| RS256 | Chaves e assinaturas maiores, sem ganho para este uso |
| Chave gerada e gravada no banco | A chave ficaria junto dos dados que ela protege |
