/** Collection: faceted filtering over every card owned, raw or slabbed. */
import { h, clear } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, compactMoney, num } from '../../core/format.js';
import { Data } from '../../systems/DataService.js';
import { CollectionSystem, SORTS, emptyFilters } from '../../systems/CollectionSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { MarketSystem } from '../../systems/MarketSystem.js';
import { InventorySystem } from '../../systems/InventorySystem.js';
import { Button, Chip, Icon, Empty } from '../components/ui.js';
import { CardTile, preloadCards } from '../components/CardView.js';
import { openInspector } from '../components/CardInspector.js';
import { openSubmitDialog } from '../components/SubmitDialog.js';

const STATUSES = [
  ['all', 'Everything'], ['raw', 'Raw'], ['graded', 'Slabbed'],
  ['auto', 'Autographs'], ['relic', 'Relics'], ['numbered', 'Numbered'], ['rookie', 'Rookies'],
];

export default function Collection({ mount, refresh }) {
  const filters = { ...emptyFilters() };
  let large = false;
  let page = 60;

  const rail = h('aside', { class: 'panel filter-rail' });
  const main = h('div', {});
  mount.append(h('div', { class: 'coll-layout' }, rail, main));

  const render = () => {
    const facets = CollectionSystem.facets();
    const cards = CollectionSystem.apply(filters);
    renderRail(facets);
    renderMain(cards);
  };

  function renderRail(facets) {
    clear(rail);
    rail.append(
      h('div', { class: 'search-box' },
        Icon('search'),
        h('input', {
          type: 'search', placeholder: 'Player, team, set...', value: filters.search,
          oninput: (e) => { filters.search = e.target.value; page = 60; render(); },
        }),
      ),
      group('Status', STATUSES.map(([id, label]) => Chip(label, {
        on: filters.status === id,
        count: id === 'all' ? facets.total : facets.status[id] ?? 0,
        onClick: () => { filters.status = id; page = 60; render(); },
      }))),
      group('Sport', [['all', 'All'], ...Data.sports().map((s) => [s, Data.sportLabel(s)])].map(([id, label]) => Chip(label, {
        on: filters.sport === id,
        count: id === 'all' ? facets.total : facets.sport[id] ?? 0,
        onClick: () => { filters.sport = id; filters.team = 'all'; page = 60; render(); },
      }))),
      group('Rarity', [['all', 'All'], ...Data.rarityTiers.map((r) => [r.id, r.label])].map(([id, label]) => Chip(label, {
        on: filters.rarity === id,
        color: id === 'all' ? undefined : Data.rarity(id).color,
        dot: id !== 'all',
        count: id === 'all' ? facets.total : facets.rarity[id] ?? 0,
        onClick: () => { filters.rarity = id; page = 60; render(); },
      }))),
      selectGroup('Franchise', filters.team, [['all', 'All franchises'], ...Data.teams
        .filter((t) => filters.sport === 'all' || t.sport === filters.sport)
        .map((t) => [t.id, `${t.city} ${t.nickname}${facets.team[t.id] ? ` (${facets.team[t.id]})` : ''}`])],
      (v) => { filters.team = v; page = 60; render(); }),
      selectGroup('Product', filters.set, [['all', 'All products'], ...Data.boxes
        .filter((b) => facets.set[b.id])
        .map((b) => [b.id, `${b.name} (${facets.set[b.id]})`])],
      (v) => { filters.set = v; page = 60; render(); }),
      Object.keys(facets.year).length > 1
        ? selectGroup('Year', filters.year, [['all', 'Any year'],
          ...Object.keys(facets.year).sort().reverse().map((y) => [y, `${y} (${facets.year[y]})`])],
        (v) => { filters.year = v; page = 60; render(); })
        : null,
      valueGroup(),
      selectGroup('Grade', filters.grade, [['all', 'Any grade'], ['none', 'Ungraded'],
        ...[10, 9, 8, 7, 6, 5, 4, 3, 2, 1].filter((g) => facets.grade[g]).map((g) => [String(g), `AGA ${g} (${facets.grade[g]})`])],
      (v) => { filters.grade = v; page = 60; render(); }),
      h('div', { class: 'divider' }),
      Button('Clear filters', { size: 'sm', variant: 'ghost', block: true, onClick: () => { Object.assign(filters, emptyFilters()); page = 60; render(); } }),
    );
  }

  function renderMain(cards) {
    clear(main);
    const summary = CollectionSystem.summary(cards);

    main.append(h('div', { class: 'coll-toolbar' },
      h('div', { class: 'row', style: { gap: 'var(--s-5)' } },
        h('div', {},
          h('div', { class: 'eyebrow' }, 'Showing'),
          h('div', { style: { fontFamily: 'var(--f-display)', fontSize: 'var(--t-lg)' } },
            `${num(cards.length)} card${cards.length === 1 ? '' : 's'} · ${compactMoney(summary.value)}`),
        ),
      ),
      h('div', { class: 'spacer' }),
      h('select', {
        class: 'input', style: { width: 'auto' },
        onchange: (e) => { filters.sort = e.target.value; render(); },
      }, ...Object.entries(SORTS).map(([k, v]) => h('option', { value: k, selected: filters.sort === k }, `Sort: ${v.label}`))),
      Button(large ? 'Compact' : 'Large', { size: 'sm', variant: 'ghost', icon: 'cards', onClick: () => { large = !large; render(); } }),
      cards.filter((c) => !c.grade && !InventorySystem.isPending(c.uid)).length
        ? Button('Grade the best 5', {
          size: 'sm', variant: 'primary', icon: 'shield',
          onClick: () => {
            const picks = cards.filter((c) => !c.grade && !InventorySystem.isPending(c.uid))
              .sort((a, b) => CardSystem.bookValue(b) - CardSystem.bookValue(a)).slice(0, 5);
            if (picks.length) openSubmitDialog(picks, { onDone: () => { render(); refresh(); } });
          },
        })
        : null,
    ));

    if (!cards.length) {
      main.append(Empty(
        S().collection.length ? 'Nothing matches those filters' : 'The vault is empty',
        S().collection.length ? 'Try clearing a filter or two.' : 'Open a hobby box and it fills up fast.',
      ));
      return;
    }

    const grid = h('div', { class: ['card-grid', large && 'is-large'] });
    const slice = cards.slice(0, page);
    for (const card of slice) {
      grid.append(CardTile(card, {
        size: 'fluid',
        value: money(CardSystem.bookValue(card) * MarketSystem.index(card.playerId)),
        onClick: (c) => openInspector(c, { onChange: () => { render(); refresh(); } }),
      }));
    }
    main.append(grid);
    preloadCards(slice);

    if (cards.length > page) {
      main.append(h('div', { style: { display: 'grid', placeItems: 'center', marginTop: 'var(--s-6)' } },
        Button(`Show ${Math.min(60, cards.length - page)} more`, { variant: 'ghost', onClick: () => { page += 60; render(); } })));
    }
  }

  /** Minimum value slider, stepped so the handle lands on useful thresholds. */
  function valueGroup() {
    const steps = [0, 1, 5, 10, 25, 50, 100, 250, 500, 1000];
    const idx = Math.max(0, steps.findIndex((v) => v >= filters.minValue));
    const label = h('span', { class: 'muted', style: { fontFamily: 'var(--f-mono)', fontSize: 'var(--t-xs)' } },
      filters.minValue ? `${money(filters.minValue)}+` : 'Any value');
    return h('div', { class: 'filter-group' },
      h('div', { class: 'row' }, h('h4', { style: { margin: 0 } }, 'Minimum value'), h('div', { class: 'spacer' }), label),
      h('input', {
        type: 'range', min: '0', max: String(steps.length - 1), value: String(idx), style: { width: '100%' },
        oninput: (e) => { label.textContent = steps[Number(e.target.value)] ? `${money(steps[Number(e.target.value)])}+` : 'Any value'; },
        onchange: (e) => { filters.minValue = steps[Number(e.target.value)]; page = 60; render(); },
      }),
    );
  }

  const group = (title, chips) => h('div', { class: 'filter-group' },
    h('h4', {}, title), h('div', { class: 'filter-chips' }, ...chips));

  const selectGroup = (title, value, options, onChange) => h('div', { class: 'filter-group' },
    h('h4', {}, title),
    h('select', { class: 'input', onchange: (e) => onChange(e.target.value) },
      ...options.map(([v, label]) => h('option', { value: v, selected: value === v }, label))),
  );

  render();
  return { destroy() {} };
}
