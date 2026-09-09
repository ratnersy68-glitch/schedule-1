/** Ledger: lifetime statistics, transaction history, set progress and settings. */
import { h, clear } from '../../core/dom.js';
import { S, store } from '../../core/store.js';
import { money, num, timeAgo, compactMoney } from '../../core/format.js';
import { EconomySystem } from '../../systems/EconomySystem.js';
import { CollectionSystem } from '../../systems/CollectionSystem.js';
import { InventorySystem } from '../../systems/InventorySystem.js';
import { MarketSystem } from '../../systems/MarketSystem.js';
import { ProgressionSystem } from '../../systems/ProgressionSystem.js';
import { SaveSystem } from '../../systems/SaveSystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { Button, Stat, Bar, Empty, Modal, toast, KV } from '../components/ui.js';
import { CardView } from '../components/CardView.js';

export default function Stats({ mount, refresh, navigate }) {
  const render = () => {
    clear(mount);
    const s = S();
    const st = s.stats;
    const best = st.bestPullUid ? InventorySystem.find(st.bestPullUid) : null;
    const collValue = EconomySystem.collectionValue((id) => MarketSystem.index(id));
    const prog = ProgressionSystem.progress();

    mount.append(h('div', { class: 'section' },
      h('div', { class: 'stat-wall' },
        Stat('Net worth', compactMoney(s.cash + collValue), { accent: 'var(--gold)', gold: true, note: `${money(s.cash)} liquid` }),
        Stat('Total spent', money(st.totalSpent), { accent: 'var(--red)' }),
        Stat('Total sales', money(st.totalSales), { accent: 'var(--green)' }),
        Stat('Grading fees', money(st.gradingFees), { accent: 'var(--violet)' }),
        Stat('Lifetime profit', money(EconomySystem.profit(), { sign: true }), { accent: EconomySystem.profit() >= 0 ? 'var(--green)' : 'var(--red)' }),
      ),
    ));

    mount.append(h('div', { class: 'section' },
      h('div', { class: 'stat-wall' },
        Stat('Boxes opened', num(st.boxesOpened), { accent: 'var(--blue)' }),
        Stat('Packs opened', num(st.packsOpened), { accent: 'var(--blue)' }),
        Stat('Cards pulled', num(st.cardsPulled), { accent: 'var(--blue)' }),
        Stat('Hits', num(st.hits), { accent: 'var(--r-epic)', note: `${num(st.autos)} autographs` }),
        Stat('Numbered', num(st.numbered), { accent: 'var(--r-rare)', note: `${num(st.oneOfOnes)} one-of-ones` }),
        Stat('Best grade', st.bestGrade ? `AGA ${st.bestGrade}` : '--', { accent: 'var(--gold)' }),
      ),
    ));

    const grid = h('div', { class: 'home-grid' });
    grid.append(bestPullPanel(best), setProgressPanel(navigate), ledgerPanel(), settingsPanel());
    mount.append(grid);
  };

  function bestPullPanel(best) {
    const panel = h('section', { class: 'panel span-4' },
      h('div', { class: 'panel-head' }, h('div', { class: 'panel-title' }, 'Best pull')));
    if (!best) { panel.append(Empty('No pulls yet', 'Your personal best lands here.', 'star')); return panel; }
    panel.append(h('div', { class: 'jewel' },
      h('div', { style: { width: '190px' } }, CardView(best, { size: 'fluid' })),
      h('div', {},
        h('div', { class: 'jewel-name' }, best.player),
        h('div', { class: 'jewel-meta' }, `${best.year} ${best.set} · ${CardSystem.label(best)}`),
      ),
      h('div', { class: 'jewel-value' }, money(CardSystem.bookValue(best))),
    ));
    return panel;
  }

  function setProgressPanel(navigate) {
    const rows = CollectionSystem.setProgress();
    const panel = h('section', { class: 'panel span-8' },
      h('div', { class: 'panel-head' },
        h('div', { class: 'panel-title' }, 'Products broken'),
        h('div', { class: 'spacer' }),
        Button('Hobby shop', { size: 'sm', variant: 'ghost', onClick: () => navigate('store') })));
    if (!rows.length) { panel.append(Empty('No products opened', 'Break a box to start the list.', 'box')); return panel; }
    const max = Math.max(...rows.map((r) => r.cards));
    for (const r of rows) {
      if (!r.set) continue;
      panel.append(h('div', { class: 'challenge' },
        h('div', { class: 'challenge-top' },
          h('span', { class: 'challenge-label' }, r.set.name),
          h('span', { class: 'challenge-reward' }, money(r.value)),
        ),
        Bar(r.cards / max, { tone: 'green' }),
        h('span', { class: 'challenge-count' }, `${num(r.cards)} cards · ${num(r.hits)} hits`),
      ));
    }
    return panel;
  }

  function ledgerPanel() {
    const rows = S().ledger.slice(0, 40);
    const panel = h('section', { class: 'panel span-8' },
      h('div', { class: 'panel-head' }, h('div', { class: 'panel-title' }, 'Transaction ledger')));
    if (!rows.length) { panel.append(Empty('No transactions', 'Buying and selling shows up here.', 'chart')); return panel; }
    const table = h('table', { class: 'ledger' },
      h('thead', {}, h('tr', {}, h('th', {}, 'When'), h('th', {}, 'Detail'), h('th', {}, 'Type'), h('th', { style: { textAlign: 'right' } }, 'Amount'))));
    const tbody = h('tbody', {});
    for (const r of rows) {
      tbody.append(h('tr', {},
        h('td', { class: 'muted' }, timeAgo(r.ts)),
        h('td', {}, r.label),
        h('td', { class: 'muted' }, r.kind),
        h('td', { class: `amt ${r.amount >= 0 ? 'pos' : 'neg'}` }, money(r.amount, { sign: true })),
      ));
    }
    table.append(tbody);
    panel.append(h('div', { style: { overflowX: 'auto' } }, table));
    return panel;
  }

  function settingsPanel() {
    const s = S();
    const panel = h('section', { class: 'panel span-4' },
      h('div', { class: 'panel-head' }, h('div', { class: 'panel-title' }, 'Settings')));
    const body = h('div', { class: 'panel-pad' });

    const toggle = (key, label, note, onChange) => {
      const sw = h('div', { class: ['switch', s.settings[key] && 'is-on'] });
      const row = h('div', {
        class: 'setting-row', role: 'switch', tabindex: '0',
        'aria-checked': String(!!s.settings[key]),
        onclick: () => {
          store.update((st) => { st.settings[key] = !st.settings[key]; });
          sw.classList.toggle('is-on', S().settings[key]);
          onChange?.(S().settings[key]);
          AudioSystem.play('click');
        },
      },
      h('div', {}, h('div', { class: 'lbl' }, label), h('div', { class: 'note' }, note)),
      sw);
      return row;
    };

    body.append(
      toggle('sfx', 'Sound effects', 'Rips, reveals and register sounds', (on) => AudioSystem.setEnabled(on)),
      toggle('fastReveal', 'Fast reveals', 'Shorten every reveal animation'),
      toggle('reduceMotion', 'Reduce motion', 'Minimal animation and no camera shake'),
      h('div', { class: 'setting-row' },
        h('div', {}, h('div', { class: 'lbl' }, 'Volume'), h('div', { class: 'note' }, 'Master level')),
        h('input', {
          type: 'range', min: '0', max: '100', value: String(Math.round(s.settings.volume * 100)),
          style: { marginLeft: 'auto', width: '120px' },
          oninput: (e) => {
            const v = Number(e.target.value) / 100;
            store.update((st) => { st.settings.volume = v; });
            AudioSystem.setVolume(v);
          },
          onchange: () => AudioSystem.play('click'),
        }),
      ),
      h('div', { class: 'divider' }),
      h('div', { class: 'stack' },
        Button('Export save', { size: 'sm', variant: 'ghost', block: true, onClick: exportSave }),
        Button('Import save', { size: 'sm', variant: 'ghost', block: true, onClick: importSave }),
        Button('Start over', { size: 'sm', variant: 'danger', block: true, onClick: confirmReset }),
      ),
      h('p', { class: 'muted', style: { fontSize: 'var(--t-xs)', marginTop: 'var(--s-4)' } },
        'All athletes, franchises, manufacturers, products and the Apex Grading Authority are fictional and unaffiliated with any real league, brand or grading company.'),
    );
    panel.append(body);
    return panel;
  }

  function exportSave() {
    const json = SaveSystem.export();
    const ta = h('textarea', {
      readonly: true, value: json,
      style: { width: '100%', height: '260px', background: 'var(--surface-sunken)', color: 'var(--text)', border: '1px solid var(--hairline)', borderRadius: 'var(--r-sm)', padding: 'var(--s-3)', fontFamily: 'var(--f-mono)', fontSize: '11px' },
    });
    const modal = Modal({
      title: 'Export save',
      width: 640,
      body: h('div', { class: 'stack' }, h('p', { class: 'muted' }, 'Copy this out to move your collection to another browser.'), ta),
      actions: [h('div', { class: 'spacer' }), Button('Copy', {
        variant: 'primary',
        onClick: async () => {
          try { await navigator.clipboard.writeText(json); toast({ title: 'Copied to clipboard', tone: 'good', icon: 'check' }); }
          catch { ta.select(); toast({ title: 'Select and copy manually', tone: 'info', icon: 'info' }); }
        },
      }), Button('Close', { variant: 'ghost', onClick: () => modal.close() })],
    });
  }

  function importSave() {
    const ta = h('textarea', {
      placeholder: 'Paste an exported save here',
      style: { width: '100%', height: '220px', background: 'var(--surface-sunken)', color: 'var(--text)', border: '1px solid var(--hairline)', borderRadius: 'var(--r-sm)', padding: 'var(--s-3)', fontFamily: 'var(--f-mono)', fontSize: '11px' },
    });
    const modal = Modal({
      title: 'Import save',
      width: 640,
      body: h('div', { class: 'stack' }, h('p', { class: 'muted' }, 'This replaces the current collection.'), ta),
      actions: [h('div', { class: 'spacer' }), Button('Cancel', { variant: 'ghost', onClick: () => modal.close() }), Button('Import', {
        variant: 'primary',
        onClick: () => {
          try { SaveSystem.import(ta.value); modal.close(); toast({ title: 'Save imported', tone: 'good', icon: 'check' }); render(); refresh(); }
          catch { toast({ title: 'That save could not be read', tone: 'bad', icon: 'error' }); }
        },
      })],
    });
  }

  function confirmReset() {
    const modal = Modal({
      title: 'Start over',
      width: 480,
      body: h('div', { class: 'stack' },
        h('p', {}, 'This wipes the collection, the vault, every slab and the ledger.'),
        KV([['Cards owned', num(InventorySystem.count())], ['Net worth', money(S().cash + EconomySystem.collectionValue())]]),
        h('p', { class: 'muted' }, 'There is no undo. Export first if you want it back.'),
      ),
      actions: [h('div', { class: 'spacer' }), Button('Keep my collection', { variant: 'ghost', onClick: () => modal.close() }), Button('Wipe everything', {
        variant: 'danger',
        onClick: () => { SaveSystem.reset(); modal.close(); toast({ title: 'Fresh start', note: 'New account funded.', tone: 'info', icon: 'gift' }); render(); refresh(); },
      })],
    });
  }

  render();
  return { destroy() {} };
}
