#!/usr/bin/env node
/**
 * Single-file build.
 *
 * Inlines every module, stylesheet, font, data file and SVG into one HTML page
 * with no network requests, so the game can be published as a standalone
 * artifact. The game source is untouched: modules are wrapped in a tiny registry
 * and `fetch` is shimmed to read from the inlined tables.
 *
 *   node tools/bundle.mjs [out.html]
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = process.argv[2] || join(ROOT, 'dist/breakroom.html');

const read = (p) => readFileSync(join(ROOT, p), 'utf8');

/**
 * Escape every non-ASCII character as \uXXXX.
 *
 * The published page inherits its charset from the host document, and a file
 * opened straight off disk has none at all. Emitting pure ASCII means the
 * bundle renders identically either way - no mojibake on the middle dots and
 * typographic marks the card fronts use.
 */
const ascii = (s) => s.replace(/[^\x00-\x7F]/g, (c) => `\\u${c.codePointAt(0).toString(16).padStart(4, '0')}`);
const walk = (dir, test, out = []) => {
  for (const e of readdirSync(join(ROOT, dir), { withFileTypes: true })) {
    const p = `${dir}/${e.name}`;
    if (e.isDirectory()) walk(p, test, out);
    else if (test(e.name)) out.push(p);
  }
  return out;
};

/* ---------------------------------------------------------------- modules */

const modules = walk('src', (n) => n.endsWith('.js'));
const ENTRY = 'src/app.js';

const resolveSpec = (fromFile, spec) => {
  const abs = resolve(dirname(join(ROOT, fromFile)), spec);
  return relative(ROOT, abs).split('\\').join('/');
};

function transform(file) {
  let src = read(file);
  const exported = new Set();
  let defaultName = null;

  // Static named imports become destructured registry lookups.
  src = src.replace(/^import\s*\{([^}]+)\}\s*from\s*['"]([^'"]+)['"];?\s*$/gm, (_, names, spec) =>
    `const {${names}} = __req(${JSON.stringify(resolveSpec(file, spec))});`);

  // Bare side-effect imports.
  src = src.replace(/^import\s*['"]([^'"]+)['"];?\s*$/gm, (_, spec) =>
    `__req(${JSON.stringify(resolveSpec(file, spec))});`);

  // `export default function Name` keeps the declaration and records the name.
  src = src.replace(/^export\s+default\s+(async\s+)?function\s+([A-Za-z_$][\w$]*)/gm, (_, asyncKw, name) => {
    defaultName = name;
    return `${asyncKw || ''}function ${name}`;
  });

  // `export function|class|const|let|var Name`
  src = src.replace(/^export\s+(async\s+)?(function|class|const|let|var)\s+([A-Za-z_$][\w$]*)/gm, (_, asyncKw, kind, name) => {
    exported.add(name);
    return `${asyncKw || ''}${kind} ${name}`;
  });

  // `export { A, B };` - the names are already declared above.
  src = src.replace(/^export\s*\{([^}]+)\};?\s*$/gm, (_, names) => {
    for (const raw of names.split(',')) {
      const n = raw.trim().split(/\s+as\s+/).pop().trim();
      if (n) exported.add(n);
    }
    return '';
  });

  // Dynamic import, but never a method call such as SaveSystem.import(...).
  src = src.replace(/(^|[^.\w$])import\(\s*['"]([^'"]+)['"]\s*\)/g, (_, lead, spec) =>
    `${lead}__reqAsync(${JSON.stringify(resolveSpec(file, spec))})`);

  const tail = [...exported].map((n) => `__x.${n} = ${n};`).join(' ')
    + (defaultName ? ` __x.default = ${defaultName};` : '');

  return `__def(${JSON.stringify(file)}, (__x) => {\n${src}\n${tail}\n});`;
}

const moduleCode = ascii(modules.map(transform).join('\n'));

/* ------------------------------------------------------------------ data */

const jsonFiles = walk('data', (n) => n.endsWith('.json'));
const svgFiles = walk('assets', (n) => n.endsWith('.svg'));

const table = (files) => `{${files.map((f) => `${JSON.stringify(f)}:${ascii(JSON.stringify(read(f)))}`).join(',\n')}}`;

/* ----------------------------------------------------------------- fonts */

const fontCss = read('assets/fonts/fonts.css').replace(/url\('\.\/([^']+)'\)/g, (_, file) => {
  const b64 = readFileSync(join(ROOT, 'assets/fonts', file)).toString('base64');
  return `url('data:font/woff2;base64,${b64}')`;
});

const css = [fontCss, 'tokens', 'base', 'components', 'card', 'screens']
  .map((n) => (n.startsWith('/*') || n.includes('@font-face') ? n : read(`styles/${n}.css`)))
  .join('\n');

/* ------------------------------------------------------------------ html */

const html = `<title>The Break Room</title>
<style>
${css}
</style>

<div id="boot" class="boot">
  <div class="boot-mark">BR</div>
  <div class="boot-name">THE BREAK ROOM</div>
  <div class="boot-bar"><i></i></div>
  <div class="boot-note">Cutting the shrink wrap</div>
</div>
<div id="app"></div>

<script type="module">
/* ---- inlined data ------------------------------------------------------ */
const __JSON = ${table(jsonFiles)};
const __SVG = ${table(svgFiles)};

/* ---- fetch shim: every asset already lives in this file ---------------- */
const __ok = (body) => Promise.resolve({
  ok: true, status: 200,
  text: () => Promise.resolve(body),
  json: () => Promise.resolve(JSON.parse(body)),
});
window.fetch = (input) => {
  const key = String(input && input.url ? input.url : input).replace(/^[./]+/, '').split('?')[0];
  if (key in __JSON) return __ok(__JSON[key]);
  if (key in __SVG) return __ok(__SVG[key]);
  return Promise.resolve({ ok: false, status: 404, text: () => Promise.resolve(''), json: () => Promise.reject(new Error('404')) });
};

/* ---- module registry --------------------------------------------------- */
const __defs = new Map();
const __cache = new Map();
const __def = (name, factory) => __defs.set(name, factory);
function __req(name) {
  if (__cache.has(name)) return __cache.get(name);
  const factory = __defs.get(name);
  if (!factory) throw new Error('module not bundled: ' + name);
  const exports = {};
  __cache.set(name, exports);
  factory(exports);
  return exports;
}
const __reqAsync = (name) => Promise.resolve(__req(name));

${moduleCode}

__req(${JSON.stringify(ENTRY)});
</script>
`;

const nonAscii = [...html.matchAll(/[^\x00-\x7F]/g)];
if (nonAscii.length) console.warn(`  warning: ${nonAscii.length} non-ASCII characters remain outside the escaped payload`);
writeFileSync(OUT, html, 'utf8');
const kb = (n) => `${(n / 1024).toFixed(0)} KB`;
console.log(`${OUT}`);
console.log(`  ${modules.length} modules, ${jsonFiles.length} data files, ${svgFiles.length} assets`);
console.log(`  css ${kb(css.length)} · js ${kb(moduleCode.length)} · svg ${kb(JSON.stringify(__SVGSIZE(svgFiles)).length)}`);
console.log(`  total ${kb(html.length)}`);
function __SVGSIZE(files) { return files.map((f) => read(f)); }
