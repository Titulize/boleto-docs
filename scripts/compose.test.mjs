// Regras do compose/docker-compose.yml que não podem regredir.
// Leitura por texto (o repositório não tem parser de YAML): o teste supõe o formato do arquivo,
// com serviços em 2 espaços de recuo e chaves em 4, sem âncoras nem fluxo `{ }`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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

const compose = stripComments(read('compose/docker-compose.yml'));
const versions = envKeys(read('.platform/versions.env'));
const example = envKeys(read('compose/.env.example'));

// Blocos de cada serviço: do nome (2 espaços) até o próximo nome ou a próxima chave da raiz.
function services() {
  const body = compose.split(/^services:\s*$/m)[1].split(/^\S/m)[0];
  return [...body.matchAll(/^ {2}([a-z0-9_-]+):\s*$([\s\S]*?)(?=^ {2}[a-z0-9_-]+:\s*$|(?![\s\S]))/gm)].map(
    (m) => ({ name: m[1], text: m[2] }),
  );
}

test('compose tem os serviços postgres, valkey e mailpit', () => {
  assert.deepEqual(
    services().map((s) => s.name),
    ['postgres', 'valkey', 'mailpit'],
  );
});

test('toda imagem vem de uma variável *_IMAGE do versions.env, com digest', () => {
  for (const s of services()) {
    const m = s.text.match(/^ {4}image:\s*(.+)$/m);
    assert.ok(m, `${s.name} sem image`);
    const v = m[1].trim().match(/^\$\{([A-Z0-9_]+_IMAGE)(:\?[^}]*)?\}$/);
    assert.ok(v, `${s.name}: image deve ser \${..._IMAGE}, encontrado ${m[1]}`);
    assert.ok(versions.has(v[1]), `${v[1]} não está no .platform/versions.env`);
    assert.match(versions.get(v[1]), /@sha256:[0-9a-f]{64}$/, `${v[1]} sem digest`);
  }
});

test('todo serviço tem healthcheck', () => {
  for (const s of services()) assert.match(s.text, /^ {4}healthcheck:/m, `${s.name} sem healthcheck`);
});

test('toda porta publicada fica em 127.0.0.1', () => {
  const ports = [...compose.matchAll(/^\s+- ['"]?([^'"\n]+:\d+)['"]?\s*$/gm)]
    .map((m) => m[1])
    .filter((p) => /:\d+$/.test(p) && !p.includes('/'));
  assert.ok(ports.length > 0);
  for (const p of ports) assert.ok(p.startsWith('127.0.0.1:'), `porta exposta na rede: ${p}`);
});

test('toda variável sem valor padrão está no .env.example ou no versions.env', () => {
  const required = [...compose.matchAll(/\$\{([A-Z0-9_]+)(:\?[^}]*)?\}/g)].map((m) => m[1]);
  assert.ok(required.length > 0);
  for (const k of required) assert.ok(example.has(k) || versions.has(k), `${k} não definida`);
});
