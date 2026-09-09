#!/usr/bin/env node
/** Renders the human-readable asset manifest from data/assets.manifest.json. */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const manifest = JSON.parse(readFileSync(join(ROOT, 'data/assets.manifest.json'), 'utf8'));

const GROUPS = [
  ['Interface backgrounds', (a) => a.folder === 'assets/ui'],
  ['Interface icons', (a) => a.folder === 'assets/icons'],
  ['Reveal effects', (a) => a.folder === 'assets/effects'],
  ['League marks', (a) => a.folder === 'assets/leagues'],
  ['Franchise crests', (a) => a.folder.startsWith('assets/teams')],
  ['Product wordmarks', (a) => a.folder === 'assets/brands'],
  ['Hobby box packaging', (a) => a.folder.startsWith('assets/boxes')],
  ['Pack wrappers', (a) => a.folder.startsWith('assets/packs')],
  ['Card templates', (a) => a.folder === 'assets/cards/templates'],
  ['Card backs', (a) => a.folder === 'assets/cards/backs'],
  ['Athlete cutouts', (a) => a.folder.startsWith('assets/cards/poses')],
  ['Parallel finishes', (a) => a.folder === 'assets/cards/foils'],
  ['Insert art', (a) => a.folder === 'assets/cards/inserts'],
  ['Grading slab', (a) => a.folder === 'assets/grading'],
];

const rows = (list) => [
  '| Key | File | Size | Format | Used for | Required |',
  '| --- | --- | --- | --- | --- | --- |',
  ...list.map((a) => `| \`${a.key}\` | \`${a.path}\` | ${a.width}x${a.height} | ${a.format} | ${a.usage} | ${a.required ? 'Required' : 'Optional'} |`),
].join('\n');

const total = manifest.assets.length;
const out = `# Asset manifest

Every image the game can display is listed here. The runtime never builds a path
by hand: \`src/core/assets.js\` loads \`data/assets.manifest.json\` and resolves art
by key, so replacing a file is a drop-in operation.

- **Total assets:** ${total}
- **Required:** ${manifest.assets.filter((a) => a.required).length}
- **Optional:** ${manifest.assets.filter((a) => !a.required).length}
- **Card artboard:** ${manifest.card.width} x ${manifest.card.height} (2.5:3.5 trading card ratio)
- **Slab artboard:** ${manifest.slab.width} x ${manifest.slab.height}, card window ${manifest.slab.window.w} x ${manifest.slab.window.h} at (${manifest.slab.window.x}, ${manifest.slab.window.y})

## Replacing artwork

1. **Same path, same name.** Drop a new \`.svg\` over the existing file. Nothing else changes.
2. **Different format or location.** Add an entry to \`data/assets.overrides.json\`:
   \`\`\`json
   { "box.BOX-NFL-PRIZM-25": "assets/overrides/prizm-photo.webp" }
   \`\`\`
   The registry prefers the override and falls back to the manifest path when the
   key is absent. Raster overrides (\`.png\`, \`.jpg\`, \`.webp\`, \`.avif\`) are rendered
   as \`<img>\`; vector files are inlined so they can inherit franchise colours.
3. **Match the artboard.** Keep the listed pixel dimensions (or the same aspect
   ratio at higher resolution) so layout is unaffected.

## Runtime colour tokens

Athlete cutouts and card templates are franchise-agnostic. When inlined they read
five CSS custom properties from their host card, so one file serves all 24 teams:

| Token | Meaning |
| --- | --- |
| \`--tp\` | Franchise primary |
| \`--tp-l\` | Primary, lightened (highlights) |
| \`--tp-d\` | Primary, darkened (shadow side) |
| \`--ts\` | Franchise secondary |
| \`--ta\` | Franchise accent / rim light |

Athlete files also expose \`text.jersey-num\`, which the card renderer rewrites with
the player's number.

## Production status

All artwork currently ships as generated vector art produced by \`tools/generate-assets.mjs\`.
It is finished, shippable art rather than grey-box placeholder, but it is vector
illustration, not licensed photography. Any slot below can be swapped for
photography or externally commissioned art with no code change.

${GROUPS.map(([title, pred]) => {
  const list = manifest.assets.filter(pred);
  return list.length ? `## ${title}\n\n${rows(list)}\n` : '';
}).filter(Boolean).join('\n')}
## Regenerating

\`\`\`bash
npm run assets     # redraw every asset + rewrite data/assets.manifest.json
npm run manifest   # rewrite this document from the manifest
npm run build      # both
\`\`\`
`;

writeFileSync(join(ROOT, 'ASSET_MANIFEST.md'), out, 'utf8');
console.log(`ASSET_MANIFEST.md written (${total} assets)`);
