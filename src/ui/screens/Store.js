/** Hobby Shop: sealed hobby boxes only, with published odds. */
import { h, clear } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, oneIn, compactMoney } from '../../core/format.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { Data } from '../../systems/DataService.js';
import { OddsSystem } from '../../systems/OddsSystem.js';
import { BreakSystem } from '../../systems/BreakSystem.js';
import { EconomySystem } from '../../systems/EconomySystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { Button, Chip, Icon, Modal, toast, KV } from '../components/ui.js';

const SPORTS = [['all', 'All sports'], ['NFL', 'Football'], ['NBA', 'Basketball'], ['MLB', 'Baseball']];

export default function Store({ mount, params, navigate, refresh }) {
  let sport = 'all';
  let sortBy = 'price';

  const render = () => {
    clear(mount);
    const level = S().level;

    mount.append(h('div', { class: 'store-filters' },
      ...SPORTS.map(([id, label]) => Chip(label, {
        on: sport === id,
        count: id === 'all' ? Data.boxes.length : Data.boxes.filter((b) => b.sport === id).length,
        onClick: () => { sport = id; render(); },
      })),
      h('div', { class: 'spacer' }),
      h('span', { class: 'section-note' }, 'Hobby configuration only. No retail products are stocked.'),
    ));

    const list = Data.boxes
      .filter((b) => sport === 'all' || b.sport === sport)
      .sort((a, b) => (sortBy === 'price' ? a.price - b.price : a.name.localeCompare(b.name)));

    const grid = h('div', { class: 'box-grid' });
    for (const box of list) grid.append(BoxCard(box, level, render, navigate, refresh));
    mount.append(grid);

    if (params.focus) {
      const el = grid.querySelector(`[data-box="${params.focus}"]`);
      el?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      params.focus = null;
    }
  };

  render();
  return { destroy() {} };
}

function BoxCard(box, level, render, navigate, refresh) {
  const locked = box.unlockLevel > level;
  const affordable = EconomySystem.canAfford(box.price);
  const card = h('article', { class: ['box-card', locked && 'is-locked'], dataset: { box: box.id } });

  const art = h('div', { class: 'box-art' },
    h('div', { class: 'box-tag' }, `${box.year} · ${Data.sportLabel(box.sport).toUpperCase()}`),
  );
  const holder = h('div', { style: { width: '100%', height: '100%', display: 'grid', placeItems: 'center' } });
  art.append(holder);
  Assets.mount(holder, AssetKeys.box(box.id), { preserveAspectRatio: 'xMidYMid meet' });
  if (locked) art.append(h('div', { class: 'box-lock' }, Icon('lock'), h('div', {}, `UNLOCKS AT LEVEL ${box.unlockLevel}`)));
  card.append(art);

  const chase = h('div', { class: 'box-chase' });
  for (const c of box.chase.slice(0, 3)) chase.append(Chip(c, { color: 'var(--r-legendary)' }));

  card.append(h('div', { class: 'box-body' },
    h('div', {},
      h('div', { class: 'box-sub' }, `${box.manufacturer.toUpperCase()} · ${box.brand.toUpperCase()}`),
      h('div', { class: 'box-name' }, box.name),
    ),
    h('p', { class: 'box-blurb' }, box.blurb),
    h('div', { class: 'box-specs' },
      spec('Packs', box.packs),
      spec('Cards/pack', box.cardsPerPack),
      spec('Hits', OddsSystem.profileFor(box).boxHits),
    ),
    chase,
    h('div', { class: 'box-foot' },
      h('div', {},
        h('div', { class: 'box-price' }, money(box.price)),
        h('div', { class: 'box-ev' }, `Avg. pull value ${compactMoney(box.estimatedValue)}`),
      ),
      h('div', { class: 'spacer' }),
      Button('Odds', { size: 'sm', variant: 'ghost', onClick: () => showOdds(box) }),
      Button('Buy', {
        size: 'sm', variant: 'gold', disabled: locked || !affordable,
        title: locked ? `Unlocks at level ${box.unlockLevel}` : !affordable ? 'Not enough cash' : '',
        onClick: () => confirmPurchase(box, render, navigate, refresh),
      }),
    ),
  ));
  return card;
}

const spec = (k, v) => h('div', { class: 'spec' }, h('div', { class: 'k' }, k.toUpperCase()), h('div', { class: 'v' }, String(v)));

function showOdds(box) {
  const { rows, profile, hitsPerBox, caseHitChance } = OddsSystem.publishedOdds(box);
  const table = h('table', { class: 'odds-table' },
    h('thead', {}, h('tr', {},
      h('th', {}, 'Card'), h('th', {}, 'Print run'), h('th', {}, 'Tier'), h('th', { style: { textAlign: 'right' } }, 'Per box'))),
  );
  const tbody = h('tbody', {});
  for (const r of rows) {
    const tier = Data.rarity(r.tier);
    tbody.append(h('tr', {},
      h('td', {}, h('span', { class: 'row', style: { gap: '8px' } },
        h('i', { class: 'dot', style: { background: tier.color, width: '8px', height: '8px', borderRadius: '50%' } }),
        r.label)),
      h('td', { class: 'muted' }, r.run ? `/${r.run}` : r.kind === 'hit' ? 'varies' : 'unnumbered'),
      h('td', { class: 'muted' }, tier.label),
      h('td', { class: 'n' }, r.chance > 0.5 ? `${(r.chance * 100).toFixed(1)}%` : oneIn(r.chance)),
    ));
  }
  table.append(tbody);

  Modal({
    title: `${box.name} - published odds`,
    width: 660,
    body: h('div', { class: 'stack' },
      h('p', { class: 'muted' }, `Every number below is the value the pull engine uses. ${hitsPerBox} autograph or memorabilia cards are guaranteed in every box, and a case hit lands ${(caseHitChance * 100).toFixed(1)}% of the time.`),
      KV([
        ['Configuration', `${box.packs} packs · ${box.cardsPerPack} cards per pack`],
        ['Guaranteed hits', `${hitsPerBox} per box`],
        ['Parallel slots', `${OddsSystem.parallelSlotsPerBox(box).toFixed(1)} per box (average)`],
        ['Case hit', `${(caseHitChance * 100).toFixed(1)}% per box`],
        ['Average pull value', money(box.estimatedValue)],
        ['Box price', money(box.price)],
      ]),
      h('div', { class: 'divider' }),
      table,
      h('p', { class: 'muted', style: { fontSize: 'var(--t-xs)', marginTop: 'var(--s-3)' } },
        'All players, franchises, products and the grading service are fictional.'),
    ),
    actions: [],
  });
}

function confirmPurchase(box, render, navigate, refresh) {
  const modal = Modal({
    title: 'Confirm purchase',
    width: 560,
    body: h('div', { class: 'stack' },
      h('div', { class: 'row', style: { gap: 'var(--s-5)' } },
        h('div', { style: { width: '150px', flex: 'none' }, ref: (el) => Assets.mount(el, AssetKeys.box(box.id), { preserveAspectRatio: 'xMidYMid meet' }) }),
        h('div', { class: 'stack' },
          h('div', { class: 'box-name' }, box.name),
          h('div', { class: 'muted' }, box.blurb),
        ),
      ),
      KV([
        ['Price', money(box.price)],
        ['Balance after', money(S().cash - box.price)],
        ['Contents', `${box.packs} packs · ${box.packs * box.cardsPerPack} cards`],
        ['Guaranteed', box.guarantees[0]],
      ]),
    ),
    actions: [
      h('div', { class: 'spacer' }),
      Button('Cancel', { variant: 'ghost', onClick: () => modal.close() }),
      Button('Buy and break it', {
        variant: 'gold', icon: 'box',
        onClick: (e) => {
          const btn = e.currentTarget;
          btn.setLoading(true);
          const entry = BreakSystem.purchase(box.id);
          btn.setLoading(false);
          modal.close();
          if (!entry) { toast({ title: 'Purchase failed', note: 'Not enough cash.', tone: 'bad', icon: 'error' }); return; }
          AudioSystem.play('purchase');
          toast({ title: 'Sealed box added', note: `${box.name} is in the vault.`, tone: 'gold', icon: 'box' });
          refresh();
          navigate('open', { vaultId: entry.id });
        },
      }),
    ],
  });
}
