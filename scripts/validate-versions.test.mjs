import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { parse } from 'smol-toml';
import { validate } from './validate-versions.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const load = () => parse(readFileSync(resolve(here, '..', 'versions.toml'), 'utf8'));

test('versions.toml real é válido', () => {
  assert.deepEqual(validate(load()), []);
});

test('falha quando imagem não tem digest', () => {
  const data = load();
  delete data.images.postgres.digest;
  const errors = validate(data);
  assert.ok(errors.some((e) => e.includes('images.postgres') && e.includes('digest')));
});

test('falha quando imagem usa tag latest', () => {
  const data = load();
  data.images.redis.tag = 'latest';
  assert.ok(validate(data).some((e) => e.includes('images.redis')));
});

test('falha para versões com faixa', () => {
  for (const bad of ['^22.3.0', '~6.0.3', '22.x', '>=1.0.0', '*', 'latest', '1.0.0+']) {
    const data = load();
    data.frontend.packages.rxjs.version = bad;
    assert.ok(
      validate(data).some((e) => e.includes('frontend.packages.rxjs')),
      `deveria rejeitar "${bad}"`,
    );
  }
});

test('falha para download sem sha256', () => {
  const data = load();
  delete data.tools.flyway.sha256_linux_x64;
  assert.ok(validate(data).some((e) => e.includes('tools.flyway')));
});

test('falha para sha256 malformado', () => {
  const data = load();
  data.runtime.node.sha256_linux_x64 = 'abc123';
  assert.ok(validate(data).some((e) => e.includes('runtime.node.sha256_linux_x64')));
});

test('falha quando falta seção obrigatória', () => {
  const data = load();
  delete data.backend.libs;
  assert.ok(validate(data).some((e) => e.includes('[backend.libs]')));
});

test('falha para schema_version diferente de 1', () => {
  const data = load();
  data.schema_version = 2;
  assert.ok(validate(data).some((e) => e.includes('schema_version')));
});
