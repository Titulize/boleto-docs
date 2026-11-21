import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import {
  applyBlock,
  applyPins,
  check,
  packageMismatches,
  parseVersions,
  sha256,
  sync,
  update,
} from './sync-versions.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');
const realToml = readFileSync(join(repoRoot, 'versions.toml'), 'utf8');

const git = (cwd, ...args) =>
  execFileSync(
    'git',
    ['-c', 'user.name=teste', '-c', 'user.email=teste@example.com', '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false', ...args],
    { cwd, stdio: 'pipe' },
  );

const tmpDirs = [];
const tmp = (prefix) => {
  const d = mkdtempSync(join(tmpdir(), `${prefix}-`));
  tmpDirs.push(d);
  return d;
};
test.after(() => {
  for (const d of tmpDirs) rmSync(d, { recursive: true, force: true });
});

/** Cria um clone git temporário que faz o papel do boleto-docs, com a tag dada. */
function makeSourceClone(tag, tomlText = realToml) {
  const dir = tmp('src');
  git(dir, 'init', '-q', '-b', 'main');
  mkdirSync(join(dir, 'scripts'), { recursive: true });
  cpSync(join(here, 'vendor'), join(dir, 'scripts', 'vendor'), { recursive: true });
  for (const f of ['sync-versions.mjs', 'validate-versions.mjs']) {
    cpSync(join(here, f), join(dir, 'scripts', f));
  }
  writeFileSync(join(dir, 'versions.toml'), tomlText);
  git(dir, 'add', '-A');
  git(dir, 'commit', '-q', '-m', 'chore: fixture');
  git(dir, 'tag', tag);
  return dir;
}

const dockerfile = (extra = '') =>
  `# topo\n# >>> platform-versions\nARG VELHO=1\n# <<< platform-versions\n\nFROM \${AL2023_IMAGE}\nRUN echo ola${extra}\n`;

test('parseVersions rejeita versions.toml inválido', () => {
  assert.throws(() => parseVersions(realToml.replace('schema_version = 1', 'schema_version = 2')), /inválido/);
});

test('applyBlock troca só o bloco e preserva o resto', () => {
  const out = applyBlock(dockerfile(), '# >>> platform-versions\nARG A=1\n# <<< platform-versions');
  assert.match(out, /^# topo\n# >>> platform-versions\nARG A=1\n# <<< platform-versions\n\nFROM/);
  assert.ok(out.endsWith('RUN echo ola\n'));
});

test('applyBlock falha sem marcadores', () => {
  assert.throws(() => applyBlock('FROM x\n', '# >>> platform-versions\n# <<< platform-versions', 'Dockerfile'), /Dockerfile.*marcadores/);
});

test('packageMismatches e applyPins preservam a formatação', () => {
  const text = `{\n  "name": "x",\n  "dependencies": {\n    "@angular/core": "^21.0.0",\n    "outro": "1.0.0"\n  },\n  "browserslist": ["a", "b"]\n}\n`;
  const pins = { '@angular/core': '22.3.0' };
  assert.equal(packageMismatches(text, pins).length, 1);
  const out = applyPins(text, pins);
  assert.match(out, /"@angular\/core": "22\.3\.0"/);
  assert.match(out, /"outro": "1\.0\.0"/);
  assert.match(out, /"browserslist": \["a", "b"\]/);
  assert.equal(packageMismatches(out, pins).length, 0);
});

test('init do backend gera catálogo, wrapper, env e bloco do Dockerfile', async () => {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('backend');
  writeFileSync(join(root, 'Dockerfile'), dockerfile());
  const changed = await update(root, { tag: 'v9.9.9', target: 'backend', fromDir: src, init: true });
  assert.ok(changed.includes('gradle/libs.versions.toml'));

  const catalog = readFileSync(join(root, 'gradle/libs.versions.toml'), 'utf8');
  assert.match(catalog, /spring-boot = "4\.1\.3"/);
  assert.match(catalog, /springdoc = \{ module = "org\.springdoc:springdoc-openapi-starter-webmvc-ui", version\.ref = "springdoc" \}/);
  assert.match(catalog, /\[plugins\][\s\S]*spring-boot = \{ id = "org\.springframework\.boot", version\.ref = "spring-boot" \}/);
  assert.match(catalog, /jacoco = "0\.8\.16"/);

  const wrapper = readFileSync(join(root, 'gradle/wrapper/gradle-wrapper.properties'), 'utf8');
  assert.match(wrapper, /distributionUrl=https\\:\/\/services\.gradle\.org\/distributions\/gradle-9\.9\.2-bin\.zip/);
  assert.match(wrapper, /distributionSha256Sum=[0-9a-f]{64}/);

  const env = readFileSync(join(root, '.platform/versions.env'), 'utf8');
  assert.match(env, /^CORRETTO_JDK_IMAGE=public\.ecr\.aws\/amazoncorretto\/amazoncorretto:25\.0\.5-al2023@sha256:[0-9a-f]{64}$/m);
  assert.match(env, /^JAVA_MAJOR=25$/m);

  const df = readFileSync(join(root, 'Dockerfile'), 'utf8');
  assert.match(df, /ARG CORRETTO_JDK_IMAGE=public\.ecr\.aws\/amazoncorretto\/amazoncorretto:25\.0\.5-al2023@sha256:/);
  assert.ok(!df.includes('VELHO'));
  assert.match(df, /FROM \$\{AL2023_IMAGE\}\nRUN echo ola\n$/);

  const mise = readFileSync(join(root, 'mise.toml'), 'utf8');
  assert.match(mise, /\[tools\]\njava = "corretto-25\.0\.5\.1\.2"\n$/);
  assert.ok(!mise.includes('node'), 'o backend não pede Node');

  const lock = JSON.parse(readFileSync(join(root, '.platform/lock.json'), 'utf8'));
  assert.equal(lock.source.sha256, sha256(realToml));
  assert.deepEqual(await check(root), []);
  for (const f of ['sync-versions.mjs', 'validate-versions.mjs', 'vendor/smol-toml.cjs']) {
    assert.ok(existsSync(join(root, '.platform', f)), `${f} copiado`);
  }
});

test('check detecta arquivo gerado editado e o sync corrige', async () => {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('backend');
  await update(root, { tag: 'v9.9.9', target: 'backend', fromDir: src, init: true });

  const wrapperPath = join(root, 'gradle/wrapper/gradle-wrapper.properties');
  writeFileSync(wrapperPath, readFileSync(wrapperPath, 'utf8').replace('9.9.2', '9.0.0'));
  const problems = await check(root);
  assert.equal(problems.length, 1);
  assert.match(problems[0], /gradle-wrapper\.properties/);

  assert.deepEqual(sync(root), ['gradle/wrapper/gradle-wrapper.properties']);
  assert.deepEqual(await check(root), []);
});

test('check detecta versions.toml local adulterado (sha256 do lock)', async () => {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('backend');
  await update(root, { tag: 'v9.9.9', target: 'backend', fromDir: src, init: true });
  const p = join(root, '.platform/versions.toml');
  writeFileSync(p, readFileSync(p, 'utf8').replace('9.9.2', '9.9.3'));
  const problems = await check(root);
  assert.ok(problems.some((m) => m.includes('sha256 do lock')));
});

test('init do frontend aplica pins no package.json e cria .node-version', async () => {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('frontend');
  writeFileSync(
    join(root, 'package.json'),
    `{\n  "name": "fe",\n  "dependencies": {\n    "@angular/core": "^21.0.0",\n    "rxjs": "7.8.2",\n    "lib-propria": "3.0.0"\n  },\n  "devDependencies": {\n    "typescript": "5.9.3"\n  }\n}\n`,
  );
  writeFileSync(join(root, 'Dockerfile'), dockerfile());
  await update(root, { tag: 'v9.9.9', target: 'frontend', fromDir: src, init: true });

  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
  assert.equal(pkg.dependencies['@angular/core'], '22.3.0');
  assert.equal(pkg.dependencies.rxjs, '7.8.2');
  assert.equal(pkg.dependencies['lib-propria'], '3.0.0');
  assert.equal(pkg.devDependencies.typescript, '6.0.3');
  assert.equal(readFileSync(join(root, '.node-version'), 'utf8'), '26.13.1\n');
  assert.match(readFileSync(join(root, 'mise.toml'), 'utf8'), /\[tools\]\nnode = "26\.13\.1"\n$/);
  assert.match(readFileSync(join(root, 'Dockerfile'), 'utf8'), /ARG NODE_SHA256_X64=[0-9a-f]{64}/);
  assert.deepEqual(await check(root), []);

  // Divergência de versão no package.json é detectada.
  writeFileSync(join(root, 'package.json'), readFileSync(join(root, 'package.json'), 'utf8').replace('6.0.3', '6.0.2'));
  assert.ok((await check(root)).some((m) => m.includes('package.json')));
});

const composeTest = `name: boleto-migrations-test\n# >>> platform-versions\nx-images:\n  velho: &velho-image x\n# <<< platform-versions\nservices: {}\n`;

/** Repositório de migrations inicializado a partir de um clone fake do boleto-docs. */
async function initMigrations() {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('migrations');
  writeFileSync(join(root, 'Dockerfile'), dockerfile());
  writeFileSync(join(root, 'compose.test.yml'), composeTest);
  await update(root, { tag: 'v9.9.9', target: 'migrations', fromDir: src, init: true });
  return root;
}

test('init de migrations gera as variáveis do Flyway por JAR e do Squawk', async () => {
  const root = await initMigrations();
  const env = readFileSync(join(root, '.platform/versions.env'), 'utf8');
  assert.match(env, /^FLYWAY_VERSION=13\.13\.0$/m);
  assert.match(env, /^FLYWAY_MAIN_CLASS=org\.flywaydb\.commandline\.Main$/m);
  assert.match(env, /^SQUAWK_VERSION=2\.73\.0$/m);
  assert.match(env, /^SQUAWK_URL=https:\/\/github\.com\/sbdchd\/squawk\/releases\/download\//m);
  assert.match(env, /^SQUAWK_SHA256=[0-9a-f]{64}$/m);
  assert.match(env, /^CORRETTO_HEADLESS_IMAGE=public\.ecr\.aws\/amazoncorretto\/amazoncorretto:25\.0\.5-al2023-headless@sha256:/m);
  assert.match(env, /^POSTGRES_IMAGE=public\.ecr\.aws\/docker\/library\/postgres:18\.7@sha256:/m);
  assert.ok(!/^FLYWAY_URL=/m.test(env) && !/^FLYWAY_SHA256=/m.test(env), 'o tarball do CLI saiu');
  assert.ok(existsSync(join(root, 'mise.toml')) && existsSync(join(root, '.node-version')));
  assert.deepEqual(await check(root), []);
});

test('o bloco ARG do Dockerfile de migrations traz o necessário para o build em dois estágios', async () => {
  const root = await initMigrations();
  const df = readFileSync(join(root, 'Dockerfile'), 'utf8');
  for (const name of [
    'AL2023_IMAGE',
    'CORRETTO_HEADLESS_IMAGE',
    'FLYWAY_VERSION',
    'FLYWAY_MAIN_CLASS',
    'SQUAWK_VERSION',
    'SQUAWK_URL',
    'SQUAWK_SHA256',
  ]) {
    assert.match(df, new RegExp(`^ARG ${name}=\\S+$`, 'm'), `${name} ausente`);
  }
  assert.ok(!df.includes('FLYWAY_URL') && !df.includes('FLYWAY_SHA256'));
});

test('flyway-jars.lock lista um JAR por linha, com sha256 e URL do Maven Central, e é estável', async () => {
  const root = await initMigrations();
  const text = readFileSync(join(root, '.platform/flyway-jars.lock'), 'utf8');
  const lines = text.split('\n').filter((l) => l && !l.startsWith('#'));
  assert.equal(lines.length, Object.keys(parseVersions(realToml).tools.flyway.jars).length);
  for (const line of lines) {
    assert.match(line, /^[0-9a-f]{64} {2}https:\/\/repo1\.maven\.org\/maven2\/\S+\/([^/\s]+)\/([^/\s]+)\/\1-\2\.jar {2}\1-\2\.jar$/);
  }
  assert.ok(lines.some((l) => l.endsWith(' flyway-core-13.13.0.jar')));
  assert.ok(lines.some((l) => l.endsWith(' postgresql-42.7.14.jar')));
  assert.deepEqual(sync(root), [], 'um segundo sync não muda nada');
  assert.equal(readFileSync(join(root, '.platform/flyway-jars.lock'), 'utf8'), text);
});

test('o bloco x-images do compose.test.yml de migrations só tem o postgres', async () => {
  const root = await initMigrations();
  const compose = readFileSync(join(root, 'compose.test.yml'), 'utf8');
  assert.match(compose, /^ {2}postgres: &postgres-image public\.ecr\.aws\/docker\/library\/postgres:18\.7@sha256:[0-9a-f]{64}$/m);
  assert.ok(!compose.includes('valkey') && !compose.includes('velho'));
  assert.match(compose, /^services: \{\}$/m);
});

test('check falha quando o flyway-jars.lock é editado à mão e o sync corrige', async () => {
  const root = await initMigrations();
  const path = join(root, '.platform/flyway-jars.lock');
  writeFileSync(path, readFileSync(path, 'utf8').replace(/^[0-9a-f]{64}/m, '0'.repeat(64)));
  const problems = await check(root);
  assert.equal(problems.length, 1);
  assert.match(problems[0], /flyway-jars\.lock/);
  assert.deepEqual(sync(root), ['.platform/flyway-jars.lock']);
  assert.deepEqual(await check(root), []);
});
test('o env do boleto-docs traz tudo que o bootstrap precisa', () => {
  const env = readFileSync(join(repoRoot, '.platform/versions.env'), 'utf8');
  for (const key of [
    'JAVA_MAJOR',
    'JAVA_CORRETTO_BUILD',
    'NODE_VERSION',
    'GRADLE_VERSION',
    'MISE_VERSION',
    'MISE_URL_LINUX_X64',
    'MISE_SHA256_LINUX_ARM64',
    'MISE_SHA256_MACOS_X64',
    'MISE_SHA256_MACOS_ARM64',
    'MISE_SHA256_WINDOWS_X64',
  ]) {
    assert.match(env, new RegExp(`^${key}=\\S+$`, 'm'), `${key} ausente`);
  }
});

test('update troca para uma tag nova', async () => {
  const src = makeSourceClone('v9.9.9');
  const root = tmp('backend');
  await update(root, { tag: 'v9.9.9', target: 'backend', fromDir: src, init: true });

  writeFileSync(join(src, 'versions.toml'), realToml.replaceAll('spring_boot = { id = "org.springframework.boot", version = "4.1.3" }', 'spring_boot = { id = "org.springframework.boot", version = "4.1.4" }'));
  git(src, 'commit', '-q', '-am', 'feat: sobe o Spring Boot');
  git(src, 'tag', 'v9.9.10');

  const changed = await update(root, { tag: 'v9.9.10', fromDir: src });
  assert.ok(changed.includes('gradle/libs.versions.toml'));
  assert.match(readFileSync(join(root, 'gradle/libs.versions.toml'), 'utf8'), /spring-boot = "4\.1\.4"/);
  assert.equal(JSON.parse(readFileSync(join(root, '.platform/lock.json'), 'utf8')).source.tag, 'v9.9.10');
  assert.deepEqual(await check(root), []);
});

test('update rejeita tag inválida e versions.toml inválido sem gravar nada', async () => {
  const root = tmp('backend');
  await assert.rejects(update(root, { tag: 'main', target: 'backend', init: true }), /vX\.Y\.Z/);

  const src = makeSourceClone('v9.9.9', realToml.replace('schema_version = 1', 'schema_version = 7'));
  await assert.rejects(update(root, { tag: 'v9.9.9', target: 'backend', fromDir: src, init: true }), /inválido/);
  assert.ok(!existsSync(join(root, '.platform')));
});

test('o boleto-docs está em dia com o próprio versions.toml', async () => {
  assert.deepEqual(await check(repoRoot), []);
});
test('check detecta edição manual no bloco gerado do Compose e o sync corrige', async () => {
  const root = tmp('docs');
  for (const f of ['.platform/lock.json', '.platform/versions.env', 'mise.toml', 'versions.toml', 'docker-compose.yml', 'docker/docs.Dockerfile', 'site/package.json']) {
    mkdirSync(dirname(join(root, f)), { recursive: true });
    cpSync(join(repoRoot, f), join(root, f));
  }
  assert.deepEqual(await check(root), []);
  const path = join(root, 'docker-compose.yml');
  const original = readFileSync(path, 'utf8');
  assert.match(original, /^ {2}postgres: &postgres-image \S+@sha256:[0-9a-f]{64}$/m);
  writeFileSync(path, original.replace(/(&postgres-image \S+@sha256:)[0-9a-f]{64}/, `$1${'0'.repeat(64)}`));
  const problems = await check(root);
  assert.ok(problems.some((m) => m.includes('docker-compose.yml') && m.includes('bloco do Compose')));
  assert.deepEqual(sync(root), ['docker-compose.yml']);
  assert.deepEqual(await check(root), []);
});
test('o lock do boleto-docs lista o docker-compose.yml', () => {
  const lock = JSON.parse(readFileSync(join(repoRoot, '.platform/lock.json'), 'utf8'));
  assert.deepEqual(lock.composeFiles, ['docker-compose.yml']);
});
