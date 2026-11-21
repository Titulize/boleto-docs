#!/usr/bin/env node
// Sincroniza as versões centrais (versions.toml) com os arquivos de cada repositório.
//
// Comandos (rode a partir da raiz do repositório):
//   node <script> sync                 regenera os arquivos derivados
//   node <script> check [--remote]     falha se houver divergência (use na CI)
//   node <script> update --tag vX.Y.Z  baixa a tag do boleto-docs e regenera
//   node <script> init --target <alvo> --tag vX.Y.Z   configura um repositório novo
//
// Opções: --root <dir> (padrão: pasta acima deste script), --from-dir <clone do boleto-docs>
// para ler a tag de um clone local em vez do GitHub.
//
// Sem dependências além do Node. Roda igual em Windows, Linux e macOS.
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { validate } from './validate-versions.mjs';

const { parse } = createRequire(import.meta.url)('./vendor/smol-toml.cjs');

export const SOURCE_REPO = 'Titulize/boleto-docs';
export const SELF_FILES = [
  'sync-versions.mjs',
  'validate-versions.mjs',
  'vendor/smol-toml.cjs',
  'vendor/smol-toml.LICENSE',
];
const BLOCK_START = '# >>> platform-versions';
const BLOCK_END = '# <<< platform-versions';

const ALL_IMAGES = [
  'amazonlinux',
  'corretto_jdk',
  'corretto_headless',
  'postgres',
  'valkey',
  'mailpit',
  'otel_lgtm',
];

/** O que cada repositório recebe. */
export const TARGETS = {
  docs: {
    images: ALL_IMAGES,
    // O boleto-docs hospeda o bootstrap do ambiente do dev, que precisa de tudo.
    vars: ['node', 'java', 'gradle', 'flyway', 'mise'],
    miseTools: ['node'],
    packages: 'docs',
    dockerArgs: ['AL2023_IMAGE', 'NODE_VERSION', 'NODE_SHA256_X64', 'NODE_SHA256_ARM64'],
    // Imagens gravadas no bloco gerado do Compose (docker-compose.yml na raiz).
    composeImages: ['postgres', 'valkey', 'mailpit'],
    files: [],
    defaults: {
      dockerfiles: ['docker/docs.Dockerfile'],
      packageJson: ['site/package.json'],
      composeFiles: ['docker-compose.yml'],
    },
  },
  backend: {
    images: ['amazonlinux', 'corretto_jdk', 'corretto_headless', 'postgres', 'valkey'],
    vars: ['java', 'gradle', 'node'],
    miseTools: ['java', 'node'],
    packages: null,
    dockerArgs: ['CORRETTO_JDK_IMAGE', 'CORRETTO_HEADLESS_IMAGE'],
    files: ['catalog', 'wrapper', 'node-version'],
    defaults: { dockerfiles: ['Dockerfile'], packageJson: [] },
  },
  frontend: {
    images: ['amazonlinux'],
    vars: ['node'],
    miseTools: ['node'],
    packages: 'frontend',
    dockerArgs: ['AL2023_IMAGE', 'NODE_VERSION', 'NODE_SHA256_X64', 'NODE_SHA256_ARM64'],
    files: ['node-version'],
    defaults: { dockerfiles: ['Dockerfile'], packageJson: ['package.json'] },
  },
  migrations: {
    images: ['amazonlinux', 'corretto_headless', 'postgres'],
    vars: ['flyway', 'squawk', 'node'],
    miseTools: ['node'],
    packages: null,
    dockerArgs: [
      'AL2023_IMAGE',
      'CORRETTO_HEADLESS_IMAGE',
      'FLYWAY_VERSION',
      'FLYWAY_MAIN_CLASS',
      'SQUAWK_VERSION',
      'SQUAWK_URL',
      'SQUAWK_SHA256',
    ],
    // Imagem do PostgreSQL no bloco gerado do Compose de teste (compose.test.yml).
    composeImages: ['postgres'],
    files: ['flyway-jars', 'node-version'],
    defaults: {
      dockerfiles: ['Dockerfile'],
      packageJson: [],
      composeFiles: ['compose.test.yml'],
    },
  },
};

// ---------------------------------------------------------------------------
// Utilitários
// ---------------------------------------------------------------------------

export const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const eol = (s) => s.replace(/\r\n/g, '\n');
const imageRef = (img) => `${img.ref}:${img.tag}@${img.digest}`;
const kebab = (s) => s.replaceAll('_', '-');

export function parseVersions(text) {
  const data = parse(text);
  const errors = validate(data);
  if (errors.length > 0) {
    throw new Error(`versions.toml inválido:\n  - ${errors.join('\n  - ')}`);
  }
  return data;
}

// ---------------------------------------------------------------------------
// Geração
// ---------------------------------------------------------------------------

/** Variáveis do alvo, na ordem de saída. */
export function envPairs(data, targetName) {
  const t = TARGETS[targetName];
  const pairs = [];
  for (const key of t.images) {
    const name = key === 'amazonlinux' ? 'AL2023' : key.toUpperCase();
    pairs.push([`${name}_IMAGE`, imageRef(data.images[key])]);
  }
  for (const v of t.vars) {
    if (v === 'node') {
      const n = data.runtime.node;
      pairs.push(['NODE_VERSION', n.version]);
      pairs.push(['NODE_SHA256_X64', n.sha256_linux_x64]);
      pairs.push(['NODE_SHA256_ARM64', n.sha256_linux_arm64]);
    } else if (v === 'java') {
      pairs.push(['JAVA_VERSION', data.runtime.java.version]);
      pairs.push(['JAVA_MAJOR', data.runtime.java.major]);
      pairs.push(['JAVA_CORRETTO_BUILD', data.runtime.java.corretto_build]);
    } else if (v === 'gradle') {
      pairs.push(['GRADLE_VERSION', data.tools.gradle.version]);
    } else if (v === 'mise') {
      const m = data.tools.mise;
      pairs.push(['MISE_VERSION', m.version]);
      for (const p of ['linux_x64', 'linux_arm64', 'macos_x64', 'macos_arm64', 'windows_x64']) {
        pairs.push([`MISE_URL_${p.toUpperCase()}`, m[`url_${p}`]]);
        pairs.push([`MISE_SHA256_${p.toUpperCase()}`, m[`sha256_${p}`]]);
      }
    } else if (v === 'flyway') {
      const f = data.tools.flyway;
      pairs.push(['FLYWAY_VERSION', f.version]);
      pairs.push(['FLYWAY_MAIN_CLASS', f.main_class]);
    } else if (v === 'squawk') {
      const s = data.tools.squawk;
      pairs.push(['SQUAWK_VERSION', s.version]);
      pairs.push(['SQUAWK_URL', s.url_linux_x64]);
      pairs.push(['SQUAWK_SHA256', s.sha256_linux_x64]);
    }
  }
  return pairs;
}

/** URL de um JAR no Maven Central. */
export const mavenUrl = (jar) =>
  `https://repo1.maven.org/maven2/${jar.group.replaceAll('.', '/')}/${jar.artifact}/${jar.version}/${jar.artifact}-${jar.version}.jar`;

/**
 * Lista dos JARs do Flyway, uma linha por JAR: "sha256  url  arquivo".
 * O estágio de download do Dockerfile do boleto-migrations lê este arquivo.
 */
export function renderFlywayJars(data, origin) {
  const lines = Object.values(data.tools.flyway.jars).map(
    (jar) => `${jar.sha256}  ${mavenUrl(jar)}  ${jar.artifact}-${jar.version}.jar`,
  );
  return `${header(origin)}${lines.join('\n')}\n`;
}

const header = (origin) =>
  `# GERADO por sync-versions.mjs a partir de versions.toml (${origin}). Não edite.\n# Para mudar uma versão, altere o versions.toml no boleto-docs e rode a sincronização.\n`;

export function renderCatalog(data, origin) {
  const versions = [];
  const libraries = [];
  const plugins = [];
  for (const [key, p] of Object.entries(data.backend.plugins)) {
    const alias = kebab(key);
    versions.push(`${alias} = "${p.version}"`);
    plugins.push(`${alias} = { id = "${p.id}", version.ref = "${alias}" }`);
  }
  for (const [key, l] of Object.entries(data.backend.libs)) {
    const alias = kebab(key);
    versions.push(`${alias} = "${l.version}"`);
    libraries.push(`${alias} = { module = "${l.module}", version.ref = "${alias}" }`);
  }
  for (const [key, tool] of Object.entries(data.backend.tools ?? {})) {
    versions.push(`${kebab(key)} = "${tool.version}"`);
  }
  return `${header(origin)}\n[versions]\n${versions.join('\n')}\n\n[libraries]\n${libraries.join('\n')}\n\n[plugins]\n${plugins.join('\n')}\n`;
}

export function renderWrapper(data, origin) {
  const g = data.tools.gradle;
  const url = g.distribution_url.replace(':', '\\:');
  return `${header(origin)}distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionSha256Sum=${g.distribution_sha256}
distributionUrl=${url}
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
`;
}

/** Arquivos inteiros gerados para o alvo: [{ path, content }]. */
export function renderFiles(data, targetName, origin) {
  const t = TARGETS[targetName];
  const files = [
    {
      path: '.platform/versions.env',
      content: `${header(origin)}${envPairs(data, targetName)
        .map(([k, v]) => `${k}=${v}`)
        .join('\n')}\n`,
    },
  ];
  if (t.files.includes('catalog')) {
    files.push({ path: 'gradle/libs.versions.toml', content: renderCatalog(data, origin) });
  }
  if (t.files.includes('wrapper')) {
    files.push({
      path: 'gradle/wrapper/gradle-wrapper.properties',
      content: renderWrapper(data, origin),
    });
  }
  if (t.files.includes('flyway-jars')) {
    files.push({ path: '.platform/flyway-jars.lock', content: renderFlywayJars(data, origin) });
  }
  if (t.files.includes('node-version')) {
    files.push({ path: '.node-version', content: `${data.runtime.node.version}\n` });
  }
  if (t.miseTools.length > 0) {
    const lines = t.miseTools.map((tool) =>
      tool === 'java'
        ? `java = "corretto-${data.runtime.java.corretto_build}"`
        : `node = "${data.runtime.node.version}"`,
    );
    files.push({ path: 'mise.toml', content: `${header(origin)}\n[tools]\n${lines.join('\n')}\n` });
  }
  return files;
}

/** Linhas ARG do bloco gerenciado dos Dockerfiles. */
export function dockerBlock(data, targetName, origin) {
  const t = TARGETS[targetName];
  const all = new Map(envPairs(data, targetName));
  const lines = [
    BLOCK_START,
    `# Gerado por sync-versions.mjs a partir de versions.toml (${origin}). Não edite este bloco.`,
  ];
  for (const name of t.dockerArgs) {
    if (!all.has(name)) throw new Error(`variável ${name} indisponível para o alvo ${targetName}`);
    lines.push(`ARG ${name}=${all.get(name)}`);
  }
  lines.push(BLOCK_END);
  return lines.join('\n');
}

/**
 * Bloco gerenciado do Compose: uma âncora YAML por imagem (com tag e digest), em `x-images`.
 * Os serviços usam `image: *<nome>-image`.
 */
export function composeBlock(data, targetName, origin) {
  const lines = [
    BLOCK_START,
    `# Gerado por sync-versions.mjs a partir de versions.toml (${origin}). Não edite este bloco.`,
    'x-images:',
  ];
  for (const key of TARGETS[targetName].composeImages) {
    lines.push(`  ${kebab(key)}: &${kebab(key)}-image ${imageRef(data.images[key])}`);
  }
  lines.push(BLOCK_END);
  return lines.join('\n');
}

/** Substitui o bloco gerenciado de um texto. Falha se os marcadores não existirem. */
export function applyBlock(text, block, label = 'arquivo') {
  const src = eol(text);
  const start = src.indexOf(BLOCK_START);
  const end = src.indexOf(BLOCK_END);
  if (start === -1 || end === -1 || end < start) {
    throw new Error(`${label}: marcadores "${BLOCK_START}" e "${BLOCK_END}" não encontrados`);
  }
  return src.slice(0, start) + block + src.slice(end + BLOCK_END.length);
}

/** Pins de pacotes npm do grupo: { pacote: versão }. */
export function packagePins(data, group) {
  const pins = {};
  for (const entry of Object.values(data[group]?.packages ?? {})) {
    pins[entry.package] = entry.version;
  }
  return pins;
}

const DEP_SECTIONS = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'];

/** Divergências entre um package.json e os pins. */
export function packageMismatches(jsonText, pins) {
  const pkg = JSON.parse(jsonText);
  const out = [];
  for (const section of DEP_SECTIONS) {
    for (const [name, version] of Object.entries(pkg[section] ?? {})) {
      if (name in pins && version !== pins[name]) {
        out.push({ name, section, found: version, expected: pins[name] });
      }
    }
  }
  return out;
}

/** Aplica os pins no texto do package.json sem reformatá-lo. */
export function applyPins(jsonText, pins) {
  let text = eol(jsonText);
  for (const m of packageMismatches(text, pins)) {
    const escaped = m.name.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
    const re = new RegExp(`("${escaped}"\\s*:\\s*")${m.found.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(")`);
    text = text.replace(re, `$1${m.expected}$2`);
  }
  return text;
}

// ---------------------------------------------------------------------------
// Contexto do repositório
// ---------------------------------------------------------------------------

function loadContext(root) {
  const lockPath = join(root, '.platform', 'lock.json');
  if (!existsSync(lockPath)) {
    throw new Error(`${lockPath} não existe. Rode "init" primeiro.`);
  }
  const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
  if (!TARGETS[lock.target]) throw new Error(`alvo desconhecido no lock: ${lock.target}`);
  const local = lock.source === 'local';
  const tomlPath = local ? join(root, 'versions.toml') : join(root, '.platform', 'versions.toml');
  const tomlText = readFileSync(tomlPath, 'utf8');
  const origin = local ? 'local' : lock.source.tag;
  return { root, lock, lockPath, local, tomlPath, tomlText, origin, data: parseVersions(tomlText) };
}

function expectedOutputs(ctx) {
  const { root, lock, data, origin } = ctx;
  const outputs = [];
  for (const f of renderFiles(data, lock.target, origin)) {
    outputs.push({ path: f.path, content: f.content, kind: 'arquivo gerado' });
  }
  const block = dockerBlock(data, lock.target, origin);
  for (const rel of lock.dockerfiles ?? []) {
    const abs = join(root, rel);
    if (!existsSync(abs)) throw new Error(`${rel} listado no lock, mas não existe`);
    outputs.push({
      path: rel,
      content: applyBlock(readFileSync(abs, 'utf8'), block, rel),
      kind: 'bloco do Dockerfile',
    });
  }
  if (TARGETS[lock.target].composeImages?.length) {
    const composeBlk = composeBlock(data, lock.target, origin);
    for (const rel of lock.composeFiles ?? []) {
      const abs = join(root, rel);
      if (!existsSync(abs)) throw new Error(`${rel} listado no lock, mas não existe`);
      outputs.push({
        path: rel,
        content: applyBlock(readFileSync(abs, 'utf8'), composeBlk, rel),
        kind: 'bloco do Compose',
      });
    }
  }
  const group = TARGETS[lock.target].packages;
  if (group) {
    const pins = packagePins(data, group);
    for (const rel of lock.packageJson ?? []) {
      const abs = join(root, rel);
      if (!existsSync(abs)) throw new Error(`${rel} listado no lock, mas não existe`);
      outputs.push({
        path: rel,
        content: applyPins(readFileSync(abs, 'utf8'), pins),
        kind: 'pins do package.json',
      });
    }
  }
  return outputs;
}

// ---------------------------------------------------------------------------
// Comandos
// ---------------------------------------------------------------------------

export function sync(root) {
  const ctx = loadContext(root);
  const changed = [];
  for (const o of expectedOutputs(ctx)) {
    const abs = join(root, o.path);
    const current = existsSync(abs) ? eol(readFileSync(abs, 'utf8')) : null;
    if (current !== o.content) {
      mkdirSync(dirname(abs), { recursive: true });
      writeFileSync(abs, o.content);
      changed.push(o.path);
    }
  }
  return changed;
}

export async function check(root, { remote = false } = {}) {
  const ctx = loadContext(root);
  const problems = [];
  if (!ctx.local) {
    const actual = sha256(readFileSync(ctx.tomlPath));
    if (actual !== ctx.lock.source.sha256) {
      problems.push(
        `.platform/versions.toml não confere com o sha256 do lock (esperado ${ctx.lock.source.sha256}, atual ${actual})`,
      );
    }
    if (remote) {
      const remoteText = await fetchRemote(ctx.lock.source.tag, 'versions.toml');
      const remoteSha = sha256(remoteText);
      if (remoteSha !== ctx.lock.source.sha256) {
        problems.push(
          `a tag ${ctx.lock.source.tag} no GitHub tem sha256 ${remoteSha}, diferente do lock (${ctx.lock.source.sha256})`,
        );
      }
    }
  }
  for (const o of expectedOutputs(ctx)) {
    const abs = join(root, o.path);
    const current = existsSync(abs) ? eol(readFileSync(abs, 'utf8')) : null;
    if (current !== o.content) {
      problems.push(`${o.path} (${o.kind}) está diferente do versions.toml`);
    }
  }
  return problems;
}

async function fetchRemote(tag, path) {
  const url = `https://raw.githubusercontent.com/${SOURCE_REPO}/${tag}/${path}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`falha ao baixar ${url}: HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

function readFromClone(fromDir, tag, path) {
  return execFileSync('git', ['-C', fromDir, 'show', `${tag}:${path}`], {
    maxBuffer: 64 * 1024 * 1024,
  });
}

async function fetchSource(tag, path, fromDir) {
  return fromDir ? readFromClone(fromDir, tag, path) : fetchRemote(tag, path);
}

export async function update(root, { tag, target, fromDir, init = false }) {
  if (!/^v\d+\.\d+\.\d+$/.test(tag ?? '')) throw new Error('informe --tag no formato vX.Y.Z');
  const lockPath = join(root, '.platform', 'lock.json');
  let lock;
  if (init) {
    if (!TARGETS[target]) {
      throw new Error(`--target deve ser um de: ${Object.keys(TARGETS).join(', ')}`);
    }
    const d = TARGETS[target].defaults;
    const present = (list) => list.filter((p) => existsSync(join(root, p)));
    lock = {
      schema: 1,
      target,
      source: { repo: SOURCE_REPO, tag, sha256: '' },
      dockerfiles: present(d.dockerfiles),
      packageJson: present(d.packageJson),
      ...(d.composeFiles ? { composeFiles: present(d.composeFiles) } : {}),
    };
  } else {
    lock = JSON.parse(readFileSync(lockPath, 'utf8'));
    if (lock.source === 'local') {
      throw new Error('este repositório usa o versions.toml local; "update" não se aplica');
    }
  }

  const tomlBuf = await fetchSource(tag, 'versions.toml', fromDir);
  parseVersions(tomlBuf.toString('utf8')); // valida antes de gravar qualquer coisa
  const platformDir = join(root, '.platform');
  mkdirSync(join(platformDir, 'vendor'), { recursive: true });
  for (const f of SELF_FILES) {
    writeFileSync(join(platformDir, f), await fetchSource(tag, `scripts/${f}`, fromDir));
  }
  writeFileSync(join(platformDir, 'versions.toml'), tomlBuf);
  lock.source = { repo: SOURCE_REPO, tag, sha256: sha256(tomlBuf) };
  writeFileSync(lockPath, `${JSON.stringify(lock, null, 2)}\n`);
  return sync(root);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const opts = { command };
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    if (a === '--remote') opts.remote = true;
    else if (a.startsWith('--')) opts[a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = rest[++i];
    else throw new Error(`argumento inesperado: ${a}`);
  }
  return opts;
}

async function main() {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const opts = parseArgs(process.argv.slice(2));
  const root = resolve(opts.root ?? join(scriptDir, '..'));
  switch (opts.command) {
    case 'sync': {
      const changed = sync(root);
      console.log(changed.length ? `atualizados:\n  ${changed.join('\n  ')}` : 'nada a atualizar');
      break;
    }
    case 'check': {
      const problems = await check(root, { remote: opts.remote });
      if (problems.length) {
        console.error(`divergências (${problems.length}):\n  - ${problems.join('\n  - ')}`);
        console.error('\nCorrija com: node <caminho do script> sync');
        process.exit(1);
      }
      console.log('versões em dia');
      break;
    }
    case 'update':
    case 'init': {
      const changed = await update(root, {
        tag: opts.tag,
        target: opts.target,
        fromDir: opts.fromDir ? resolve(opts.fromDir) : undefined,
        init: opts.command === 'init',
      });
      console.log(`tag ${opts.tag} aplicada.${changed.length ? `\natualizados:\n  ${changed.join('\n  ')}` : ''}`);
      break;
    }
    default:
      console.error('uso: sync-versions.mjs <sync|check [--remote]|update --tag vX.Y.Z|init --target <alvo> --tag vX.Y.Z> [--root dir] [--from-dir dir]');
      process.exit(2);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(`erro: ${e.message}`);
    process.exit(1);
  });
}
