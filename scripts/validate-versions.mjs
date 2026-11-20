#!/usr/bin/env node
// Valida o versions.toml central.
// Uso: node scripts/validate-versions.mjs [caminho/para/versions.toml]
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { parse } from 'smol-toml';

const SHA256 = /^[0-9a-f]{64}$/;
const DIGEST = /^sha256:[0-9a-f]{64}$/;
const EXACT_VERSION = /^v?\d+(\.\d+){0,4}([-.][0-9A-Za-z]+)*$/;
const FORBIDDEN_RANGE = /[\^~*><=|\s]|latest|\+|\.x$/i;

const REQUIRED_SECTIONS = [
  'runtime.java',
  'runtime.node',
  'tools.gradle',
  'tools.flyway',
  'images.amazonlinux',
  'images.corretto_jdk',
  'images.corretto_headless',
  'images.postgres',
  'images.valkey',
  'images.mailpit',
  'backend.plugins',
  'backend.libs',
  'frontend.packages',
];

const isTable = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const get = (obj, path) => path.split('.').reduce((acc, k) => (isTable(acc) ? acc[k] : undefined), obj);

function checkVersion(errors, where, value) {
  if (typeof value !== 'string' || value === '') {
    errors.push(`${where}: versão ausente`);
  } else if (FORBIDDEN_RANGE.test(value) || !EXACT_VERSION.test(value)) {
    errors.push(`${where}: versão "${value}" não é exata (sem faixas, "latest", "+" ou ".x")`);
  }
}

function checkHash(errors, where, value, regex, label) {
  if (typeof value !== 'string' || !regex.test(value)) {
    errors.push(`${where}: ${label} ausente ou inválido`);
  }
}

export function validate(data) {
  const errors = [];

  if (data.schema_version !== 1) {
    errors.push('schema_version deve ser 1');
  }

  for (const section of REQUIRED_SECTIONS) {
    if (!isTable(get(data, section))) {
      errors.push(`seção obrigatória ausente: [${section}]`);
    }
  }

  // Imagens: tag exata e digest.
  for (const [name, image] of Object.entries(data.images ?? {})) {
    const where = `images.${name}`;
    if (typeof image.ref !== 'string' || image.ref === '') {
      errors.push(`${where}: ref ausente`);
    }
    if (typeof image.tag !== 'string' || image.tag === '' || /latest/i.test(image.tag)) {
      errors.push(`${where}: tag ausente ou "latest"`);
    }
    checkHash(errors, where, image.digest, DIGEST, 'digest (sha256:...)');
  }

  // Runtime e ferramentas: versão exata. Downloads: URL https e sha256.
  for (const group of ['runtime', 'tools']) {
    for (const [name, entry] of Object.entries(data[group] ?? {})) {
      const where = `${group}.${name}`;
      checkVersion(errors, where, entry.version);
      for (const [key, value] of Object.entries(entry)) {
        if (key.startsWith('url_') || key === 'distribution_url') {
          if (typeof value !== 'string' || !value.startsWith('https://')) {
            errors.push(`${where}.${key}: URL https ausente`);
          }
        }
        if (key.startsWith('sha256_') || key === 'distribution_sha256') {
          checkHash(errors, `${where}.${key}`, value, SHA256, 'sha256');
        }
      }
      // Todo url_X exige sha256_X correspondente.
      for (const key of Object.keys(entry).filter((k) => k.startsWith('url_'))) {
        const sha = `sha256_${key.slice(4)}`;
        if (!(sha in entry)) {
          errors.push(`${where}: ${key} sem ${sha}`);
        }
      }
      if ('distribution_url' in entry && !('distribution_sha256' in entry)) {
        errors.push(`${where}: distribution_url sem distribution_sha256`);
      }
    }
  }

  // Bibliotecas, plugins e pacotes: identificador e versão exata.
  const idKeys = { module: 'libs', id: 'plugins', package: 'packages' };
  for (const group of ['backend', 'frontend', 'docs']) {
    for (const [section, entries] of Object.entries(data[group] ?? {})) {
      for (const [name, entry] of Object.entries(entries)) {
        const where = `${group}.${section}.${name}`;
        if (section === 'tools') {
          checkVersion(errors, where, entry.version);
          continue;
        }
        const hasId = Object.keys(idKeys).some((k) => typeof entry[k] === 'string' && entry[k] !== '');
        if (!hasId) {
          errors.push(`${where}: falta "module", "id" ou "package"`);
        }
        checkVersion(errors, where, entry.version);
      }
    }
  }

  return errors;
}

function main() {
  const here = dirname(fileURLToPath(import.meta.url));
  const file = resolve(process.argv[2] ?? resolve(here, '..', 'versions.toml'));
  let data;
  try {
    data = parse(readFileSync(file, 'utf8'));
  } catch (e) {
    console.error(`Erro ao ler ${file}: ${e.message}`);
    process.exit(1);
  }
  const errors = validate(data);
  if (errors.length > 0) {
    console.error(`versions.toml inválido (${errors.length} problema(s)):`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }
  console.log(`versions.toml válido: ${file}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
