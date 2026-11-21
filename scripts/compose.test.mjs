// Regras do docker-compose.yml (raiz) que não podem regredir.
// Leitura por texto (o repositório não tem parser de YAML): o teste supõe o formato do arquivo,
// com serviços em 2 espaços de recuo e chaves em 4, sem fluxo `{ }`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(resolve(root, p), 'utf8');
const stripComments = (text) =>
  text
    .split(/\r?\n/)
    .filter((l) => !/^\s*#/.test(l))
    .join('\n');
const envKeys = (text) =>
  new Map(
    text
      .split(/\r?\n/)
      .filter((l) => /^[A-Z0-9_]+=/.test(l))
      .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
  );
const compose = stripComments(read('docker-compose.yml'));
const example = envKeys(read('.env.example'));
// Âncoras do bloco gerado: nome -> imagem.
const anchors = new Map(
  [...compose.matchAll(/^ {2}[a-z0-9_-]+:\s+&([a-z0-9-]+)\s+(\S+)\s*$/gm)].map((m) => [m[1], m[2]]),
);
// Blocos de cada serviço: do nome (2 espaços) até o próximo nome ou a próxima chave da raiz.
function services() {
  const body = compose.split(/^services:\s*$/m)[1].split(/^\S/m)[0];
  return [...body.matchAll(/^ {2}([a-z0-9_-]+):\s*$([\s\S]*?)(?=^ {2}[a-z0-9_-]+:\s*$|(?![\s\S]))/gm)].map(
    (m) => ({ name: m[1], text: m[2] }),
  );
}
const infra = () => services().filter((s) => !/^ {4}profiles:/m.test(s.text));
test('o compose usa o projeto boleto-dev (os volumes do dev continuam os mesmos)', () => {
  assert.match(compose, /^name: boleto-dev\s*$/m);
});
test('só existe o compose da raiz (arquivos rastreados de compose/ foram removidos)', () => {
  // Não testa a pasta: um compose/.env do dev (ignorado pelo git) pode continuar nela (ADR 0022).
  for (const p of [
    'compose/docker-compose.yml',
    'compose/.env.example',
    'compose/dev.ps1',
    'compose/dev.sh',
    'compose/tests/verify.ps1',
    'compose/tests/verify.sh',
  ])
    assert.ok(!existsSync(resolve(root, p)), `${p} foi removido (ADR 0022)`);
});
test('postgres, valkey e mailpit sobem sem profile; o site fica no profile docs', () => {
  assert.deepEqual(
    infra().map((s) => s.name),
    ['postgres', 'valkey', 'mailpit'],
  );
  const docs = services().find((s) => s.name === 'docs');
  assert.ok(docs, 'serviço docs ausente');
  assert.match(docs.text, /^ {4}profiles:\s*\[docs\]\s*$/m);
});
test('o flyway fica no profile migrations, roda uma vez e espera o banco saudável', () => {
  const flyway = services().find((s) => s.name === 'flyway');
  assert.ok(flyway, 'serviço flyway ausente');
  assert.match(flyway.text, /^ {4}profiles:\s*\[migrations, backend\]\s*$/m);
  assert.match(flyway.text, /^ {4}restart:\s*['"]?no['"]?\s*$/m);
  assert.match(flyway.text, /^ {6}postgres:\s*\n {8}condition:\s*service_healthy\s*$/m);
  assert.match(flyway.text, /^ {6}FLYWAY_URL:\s*jdbc:postgresql:\/\/postgres:5432\//m);
  assert.match(flyway.text, /^ {6}FLYWAY_PLACEHOLDERS_APP_PASSWORD:/m);
});
test('o backend fica no profile backend, em 127.0.0.1, depois do banco saudável e da migração', () => {
  const backend = services().find((s) => s.name === 'backend');
  assert.ok(backend, 'serviço backend ausente');
  assert.match(backend.text, /^ {4}profiles:\s*\[backend\]\s*$/m);
  assert.match(backend.text, /^ {4}restart:\s*['"]?no['"]?\s*$/m);
  assert.match(backend.text, /^ {6}- '127\.0\.0\.1:\$\{BACKEND_PORT:-8080\}:8080'\s*$/m);
  assert.match(backend.text, /^ {6}postgres:\s*\n {8}condition:\s*service_healthy\s*$/m);
  assert.match(backend.text, /^ {6}flyway:\s*\n {8}condition:\s*service_completed_successfully\s*$/m);
  assert.doesNotMatch(backend.text, /^ {6}valkey:/m, 'o backend ainda não depende do valkey');
  assert.match(backend.text, /^ {4}healthcheck:/m);
  // Imagem construída localmente (build), por isso sem âncora do bloco gerado.
  assert.match(backend.text, /^ {4}image:\s*boleto-backend:dev\s*$/m);
  assert.match(backend.text, /^ {6}SPRING_DATASOURCE_USERNAME:\s*boleto_app\s*$/m);
});test('toda imagem de infraestrutura vem de uma âncora do bloco gerado, com digest', () => {
  for (const s of infra()) {
    const m = s.text.match(/^ {4}image:\s*(.+)$/m);
    assert.ok(m, `${s.name} sem image`);
    const a = m[1].trim().match(/^\*([a-z0-9-]+)$/);
    assert.ok(a, `${s.name}: image deve ser uma âncora (*nome-image), encontrado ${m[1]}`);
    assert.ok(anchors.has(a[1]), `âncora ${a[1]} não existe no bloco gerado`);
    assert.match(anchors.get(a[1]), /@sha256:[0-9a-f]{64}$/, `${a[1]} sem digest`);
  }
});
test('todo serviço de infraestrutura tem healthcheck (o --wait depende dele)', () => {
  for (const s of infra()) assert.match(s.text, /^ {4}healthcheck:/m, `${s.name} sem healthcheck`);
});
test('toda porta publicada fica em 127.0.0.1', () => {
  const ports = [...compose.matchAll(/^\s+- ['"]?([^'"\n]+:\d+)['"]?\s*$/gm)]
    .map((m) => m[1])
    .filter((p) => /:\d+$/.test(p) && !p.includes('/'));
  assert.ok(ports.length > 0);
  for (const p of ports) assert.ok(p.startsWith('127.0.0.1:'), `porta exposta na rede: ${p}`);
});
test('toda variável tem valor padrão no compose e consta no .env.example', () => {
  const vars = [...compose.matchAll(/\$\{([A-Z0-9_]+)([^}]*)\}/g)];
  assert.ok(vars.length > 0);
  for (const [, name, rest] of vars) {
    assert.match(rest, /^:-[^}]+$/, `${name} sem valor padrão (o .env deve ser opcional)`);
    assert.ok(example.has(name), `${name} não consta no .env.example`);
  }
});
test('os valores do .env.example são os padrões do compose', () => {
  for (const [, name, def] of compose.matchAll(/\$\{([A-Z0-9_]+):-([^}]+)\}/g)) {
    assert.equal(example.get(name), def, `${name}: .env.example diferente do padrão do compose`);
  }
});
