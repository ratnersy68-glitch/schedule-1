/** Marketplace: live player index, headlines and consignment. */
import { h, clear } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, compactMoney, num, timeAgo } from '../../core/format.js';
import { Data } from '../../systems/DataService.js';
import { MarketSystem } from '../../systems/MarketSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { CollectionSystem } from '../../systems/CollectionSystem.js';
import { EconomySystem } from '../../systems/EconomySystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { Button, Stat, Chip, Empty, Modal, KV, toast } from '../components/ui.js';
import { CardView, preloadCards } from '../components/CardView.js';
import { openInspector } from '../components/CardInspector.js';

const SELL_MODES = [
  ['dupes', 'Duplicates'],
  ['commons', 'Under $5'],
  ['best', 'Highest value'],
  ['all', 'Everything raw'],
];

export default function Market({ mount, refresh, navigate }) {
  let mode = 'best';
  let limit = 24;

  const render = () => {
    clear(mount);
    const summary = CollectionSystem.summary();
    const { up, down } = MarketSystem.movers(6);

    mount.append(h('div', { class: 'section' },
      h('div', { class: 'stat-wall' },
        Stat('Collection value', compactMoney(summary.value), { accent: 'var(--gold)', gold: true, note: `${num(summary.count)} cards` }),
        Stat('Lifetime sales', money(S().stats.totalSales), { accent: 'var(--green)' }),
        Stat('Marketplace fee', `${Math.round(Data.economy.sellFeeRate * 100)}%`, { accent: 'var(--red)', note: 'Deducted from every sale' }),
        Stat('Market tick', `#${num(S().market.tick)}`, { accent: 'var(--blue)', note: 'Prices move on their own' }),
      ),
    ));

    const grid = h('div', { class: 'market-grid' });
    grid.append(moversPanel('Climbing', up, 'pos'), moversPanel('Cooling', down, 'neg'), newsPanel(), sellPanel());
    mount.append(grid);
  };

  function moversPanel(title, rows, tone) {
    const panel = h('section', { class: 'panel span-4' },
      h('div', { class: 'panel-head' }, h('div', { class: 'panel-title' }, title)));
    for (const r of rows) {
      const team = Data.team(r.player.team);
      panel.append(h('div', { class: 'mover-row' },
        h('div', { class: 'truncate' },
          h('div', { class: 'nm truncate' }, r.player.name),
          h('div', { class: 'tm truncate' }, `${team.city} ${team.nickname} · ${r.player.position}${r.player.rookie ? ' · RC' : ''}`),
        ),
        h('div', { class: `ch ${r.change >= 0 ? 'pos' : 'neg'}` }, `${r.change >= 0 ? '+' : ''}${r.change.toFixed(1)}%`),
      ));
    }
    return panel;
  }

  function newsPanel() {
    const news = MarketSystem.news(8);
    const panel = h('section', { class: 'panel span-4' },
      h('div', { class: 'panel-head' }, h('div', { class: 'panel-title' }, 'The wire')));
    if (!news.length) { panel.append(Empty('Quiet week', 'Headlines move player prices.', 'chart')); return panel; }
    for (const n of news) {
      panel.append(h('div', { class: 'news-row' },
        h('div', {},
          h('div', { class: 'hl' }, n.headline),
          h('div', { class: 'tm', style: { fontSize: 'var(--t-xs)', color: 'var(--text-faint)' } }, timeAgo(n.ts)),
        ),
        h('div', { class: `mv ${n.change >= 0 ? 'pos' : 'neg'}` }, `${n.change >= 0 ? '+' : ''}${(n.change * 100).toFixed(1)}%`),
      ));
    }
    return panel;
  }

  function sellPanel() {
    const raw = S().collection.filter((c) => !c.grade || c.grade);
    let list = [...raw];
    if (mode === 'commons') list = list.filter((c) => CardSystem.bookValue(c) < 5);
    if (mode === 'best') list = list.sort((a, b) => CardSystem.bookValue(b) - CardSystem.bookValue(a));
    if (mode === 'all') list = list.filter((c) => !c.grade);
    if (mode === 'dupes') {
      const seen = new Map();
      list = list.filter((c) => {
        const key = `${c.playerId}|${c.parallel}|${c.cardType}`;
        const n = (seen.get(key) ?? 0) + 1;
        seen.set(key, n);
        return n > 1;
      });
    }
    if (mode !== 'best') list.sort((a, b) => CardSystem.bookValue(b) - CardSystem.bookValue(a));

    const total = list.reduce((a, c) => a + MarketSystem.quote(c).net, 0);
    const panel = h('section', { class: 'panel span-12' },
      h('div', { class: 'panel-head' },
        h('div', { class: 'panel-title' }, 'Consignment desk'),
        h('div', { class: 'spacer' }),
        ...SELL_MODES.map(([id, label]) => Chip(label, { on: mode === id, onClick: () => { mode = id; limit = 24; render(); } })),
      ),
    );

    if (!list.length) {
      panel.append(Empty('Nothing to consign', 'Open a box, then come back and cash out the filler.', 'sell'));
      return panel;
    }

    panel.append(h('div', { class: 'row', style: { padding: 'var(--s-3) var(--s-5)', borderTop: '1px solid var(--hairline)' } },
      h('span', { class: 'muted' }, `${num(list.length)} cards · ${money(total)} after fees`),
      h('div', { class: 'spacer' }),
      Button(`Sell all ${mode === 'best' ? 'listed' : SELL_MODES.find((m) => m[0] === mode)[1].toLowerCase()}`, {
        variant: 'gold', size: 'sm', icon: 'cash', sound: 'sell',
        onClick: () => confirmBulk(list),
      }),
    ));

    for (const card of list.slice(0, limit)) {
      const q = MarketSystem.quote(card);
      panel.append(h('div', { class: 'sell-row' },
        h('div', { style: { width: '48px', flex: 'none', cursor: 'pointer' }, onclick: () => openInspector(card, { onChange: () => { render(); refresh(); } }) },
          CardView(card, { size: 'fluid', tilt: false, effects: false })),
        h('div', { class: 'info truncate' },
          h('div', { class: 'nm truncate' }, card.player),
          h('div', { class: 'tr truncate' }, `${card.year} ${card.set} · ${CardSystem.label(card)}${card.grade ? ` · AGA ${card.grade.grade}` : ''}`),
        ),
        h('div', { class: 'qt' },
          h('b', {}, money(q.net)),
          h('span', {}, `book ${money(q.book)} · idx ${q.index.toFixed(2)}x`),
        ),
        Button('Sell', {
          size: 'sm', sound: 'sell',
          onClick: () => {
            const r = MarketSystem.sell(card.uid);
            if (r) {
              AudioSystem.play('cash');
              toast({ title: 'Sold', note: `${card.player} · ${money(r.quote.net)}`, tone: 'gold', icon: 'cash', ttl: 2600 });
              render(); refresh();
            }
          },
        }),
      ));
    }

    if (list.length > limit) {
      panel.append(h('div', { style: { display: 'grid', placeItems: 'center', padding: 'var(--s-4)' } },
        Button(`Show ${Math.min(24, list.length - limit)} more`, { variant: 'ghost', size: 'sm', onClick: () => { limit += 24; render(); } })));
    }
    return panel;
  }

  function confirmBulk(list) {
    const total = list.reduce((a, c) => a + MarketSystem.quote(c).net, 0);
    const best = list.reduce((b, c) => (!b || CardSystem.bookValue(c) > CardSystem.bookValue(b) ? c : b), null);
    const modal = Modal({
      title: `Sell ${list.length} cards`,
      width: 520,
      body: h('div', { class: 'stack' },
        KV([
          ['Cards', num(list.length)],
          ['Gross', money(list.reduce((a, c) => a + MarketSystem.quote(c).gross, 0))],
          ['Marketplace fee', money(-list.reduce((a, c) => a + MarketSystem.quote(c).fee, 0)), 'neg'],
          ['Net proceeds', money(total), 'pos'],
          ['Best card leaving', best ? `${best.player} · ${CardSystem.label(best)}` : '-'],
        ]),
        h('p', { class: 'muted' }, 'Selling several copies of the same player nudges that player\'s index down. This cannot be undone.'),
      ),
      actions: [
        h('div', { class: 'spacer' }),
        Button('Cancel', { variant: 'ghost', onClick: () => modal.close() }),
        Button('Confirm sale', {
          variant: 'gold', icon: 'cash', sound: 'sell',
          onClick: () => {
            let net = 0;
            for (const c of list) { const r = MarketSystem.sell(c.uid); if (r) net += r.quote.net; }
            modal.close();
            AudioSystem.play('cash');
            toast({ title: `${list.length} cards sold`, note: money(net), tone: 'gold', icon: 'cash' });
            render(); refresh();
          },
        }),
      ],
    });
  }

  render();
  return { destroy() {} };
}
