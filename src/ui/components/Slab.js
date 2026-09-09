/** Encapsulated graded card: acrylic shell, printed label, sealed card window. */
import { h } from '../../core/dom.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { GradingSystem } from '../../systems/GradingSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { CardView } from './CardView.js';

export function Slab(card, { size = 'md', tilt = false } = {}) {
  const grade = card.grade?.grade ?? 10;
  const band = GradingSystem.labelBand(grade);

  const el = h('div', { class: `slab slab-${size}`, dataset: { band, grade } });
  const labelArt = h('div', { class: 'slab-label-art' });
  const code = h('div', { class: 'sl-code' });

  const label = h('div', { class: 'slab-label' },
    labelArt,
    h('div', { class: 'slab-label-copy' },
      h('div', { class: 'sl-player' }, card.player),
      h('div', { class: 'sl-set' }, `${card.year} ${card.set} #${card.cardNumber}`),
      h('div', { class: 'sl-treat' }, CardSystem.label(card)),
      h('div', { class: 'sl-grade' },
        h('div', { class: 'g-name' }, GradingSystem.gradeName(grade)),
        h('div', { class: 'g-num' }, String(grade)),
      ),
      h('div', { class: 'sl-cert' }, `CERT ${card.grade?.cert ?? '00000000'}`),
      code,
    ),
  );

  const window_ = h('div', { class: 'slab-window' });
  window_.append(CardView(card, { size: 'fluid', tilt, effects: true }));

  const shell = h('div', { class: 'slab-shell' });
  el.append(window_, label, shell);

  Assets.mount(shell, AssetKeys.slabShell(), { preserveAspectRatio: 'none' });
  Assets.mount(labelArt, AssetKeys.slabLabel(band), { preserveAspectRatio: 'none' });
  Assets.mount(code, AssetKeys.slabBarcode(), { preserveAspectRatio: 'none' });

  el.card = card;
  return el;
}

export function slabAssetKeys() {
  return [AssetKeys.slabShell(), AssetKeys.slabBarcode(), AssetKeys.graderMark(),
    ...['standard', 'gold', 'black'].map((b) => AssetKeys.slabLabel(b))];
}
