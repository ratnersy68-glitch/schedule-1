/** Apex Grading Authority: queue cards, wait out the turnaround, open the slabs. */
import { h, clear, wait } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, num, relativeTime, timeAgo } from '../../core/format.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { Data } from '../../systems/DataService.js';
import { GradingSystem } from '../../systems/GradingSystem.js';
import { InventorySystem } from '../../systems/InventorySystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { ProgressionSystem } from '../../systems/ProgressionSystem.js';
import { AnimationSystem } from '../../systems/AnimationSystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { burst } from '../../effects/particles.js';
import { Button, Stat, Chip, Empty, Modal, KV, Bar, toast, Icon } from '../components/ui.js';
import { CardView, CardTile, preloadCards } from '../components/CardView.js';
import { Slab, slabAssetKeys } from '../components/Slab.js';
import { openSubmitDialog } from '../components/SubmitDialog.js';

export default function Grading({ mount, refresh }) {
  let selection = new Set();
  let sortBy = 'value';
  let timer = null;

  Assets.preload(slabAssetKeys());

  const render = () => {
    clear(mount);
    const s = S();
    const pending = GradingSystem.pending();
    const ready = GradingSystem.ready();
    const graded = InventorySystem.graded();
    const gemRate = s.stats.gemRate.graded ? (s.stats.gemRate.tens / s.stats.gemRate.graded) * 100 : 0;

    mount.append(h('div', { class: 'section' },
      h('div', { class: 'stat-wall' },
        Stat('At the grader', num(pending.length), { accent: 'var(--blue)', note: ready.length ? `${ready.length} ready to open` : 'None ready yet' }),
        Stat('Slabs owned', num(graded.length), { accent: 'var(--gold)', gold: true }),
        Stat('Gem rate', s.stats.gemRate.graded ? `${gemRate.toFixed(0)}%` : '--', { accent: 'var(--violet)', note: `${num(s.stats.gradedCount)} graded` }),
        Stat('Fees paid', money(s.stats.gradingFees), { accent: 'var(--red)', note: `Best grade: AGA ${s.stats.bestGrade || '-'}` }),
      ),
    ));

    mount.append(h('div', { class: 'grade-layout' }, submissionsPanel(pending, ready), queuePanel()));

    if (graded.length) {
      const panel = h('section', { class: 'panel section', style: { marginTop: 'var(--s-5)' } },
        h('div', { class: 'panel-head' },
          h('div', { class: 'panel-title' }, 'The slab case'),
          h('div', { class: 'spacer' }),
          h('span', { class: 'section-note' }, `${num(graded.length)} encapsulated cards`)),
      );
      const grid = h('div', { class: 'card-grid is-large', style: { padding: 'var(--s-5)' } });
      for (const card of graded.sort((a, b) => b.grade.grade - a.grade.grade || CardSystem.bookValue(b) - CardSystem.bookValue(a)).slice(0, 18)) {
        const tile = h('div', { class: 'card-tile', role: 'button', tabindex: '0' }, Slab(card, { size: 'fluid' }),
          h('div', { class: 'card-cap' }, h('b', {}, card.player), h('span', { class: 'val' }, money(CardSystem.bookValue(card)))));
        tile.addEventListener('click', () => import('../components/CardInspector.js').then((m) => m.openInspector(card, { onChange: () => { render(); refresh(); } })));
        grid.append(tile);
      }
      panel.append(grid);
      mount.append(panel);
    }

    clearInterval(timer);
    if (pending.some((p) => Date.now() < p.readyAt)) timer = setInterval(tickTimers, 1000);
  };

  function tickTimers() {
    let needsRender = false;
    for (const el of mount.querySelectorAll('[data-ready-at]')) {
      const at = Number(el.dataset.readyAt);
      if (Date.now() >= at) { needsRender = true; break; }
      el.textContent = relativeTime(at - Date.now());
    }
    if (needsRender) { render(); refresh(); }
  }

  function submissionsPanel(pending, ready) {
    const panel = h('section', { class: 'panel' },
      h('div', { class: 'panel-head' },
        h('div', { class: 'panel-title' }, 'Submissions'),
        h('div', { class: 'spacer' }),
        ready.length ? Button(`Open all ${ready.length}`, { size: 'sm', variant: 'gold', icon: 'sparkle', onClick: () => openAll(ready) }) : null,
      ),
    );
    if (!pending.length) {
      panel.append(Empty('No open submissions', 'Pick cards on the right and send them in.', 'shield'));
      return panel;
    }
    for (const sub of pending) {
      const tier = GradingSystem.tier(sub.tier);
      const isReady = Date.now() >= sub.readyAt;
      const cards = sub.cardUids.map((u) => InventorySystem.find(u)).filter(Boolean);
      const stack = h('div', { class: 'stack-cards' });
      for (const c of cards.slice(0, 4)) stack.append(h('div', { style: { width: '40px' } }, CardView(c, { size: 'fluid', tilt: false, effects: false, faceDown: !isReady })));

      const total = Math.max(1, sub.readyAt - sub.submittedAt);
      const done = Math.min(1, (Date.now() - sub.submittedAt) / total);

      panel.append(h('div', { class: 'sub-row' },
        stack,
        h('div', { style: { minWidth: '0', flex: '1' } },
          h('div', { style: { fontWeight: '600' } }, `${cards.length} card${cards.length > 1 ? 's' : ''} · ${tier.label}`),
          h('div', { class: 'muted', style: { fontSize: 'var(--t-xs)' } }, `Submitted ${timeAgo(sub.submittedAt)} · fees ${money(sub.fee)}`),
          h('div', { style: { marginTop: '6px', maxWidth: '260px' } }, Bar(done, { tone: isReady ? 'gold' : '' })),
        ),
        isReady
          ? Button('Open the slabs', { variant: 'gold', size: 'sm', icon: 'sparkle', onClick: () => openSubmission(sub) })
          : h('span', { class: 'sub-timer', dataset: { readyAt: String(sub.readyAt) } }, relativeTime(sub.readyAt - Date.now())),
      ));
    }
    return panel;
  }

  function queuePanel() {
    const gradable = InventorySystem.gradable();
    const sorted = [...gradable].sort((a, b) => (sortBy === 'value'
      ? CardSystem.bookValue(b) - CardSystem.bookValue(a)
      : GradingSystem.preview(b, 'express').confidence - GradingSystem.preview(a, 'express').confidence));

    const panel = h('aside', { class: 'panel' },
      h('div', { class: 'panel-head' },
        h('div', { class: 'panel-title' }, 'Build a submission'),
        h('div', { class: 'spacer' }),
        Chip('By value', { on: sortBy === 'value', onClick: () => { sortBy = 'value'; render(); } }),
      ),
    );

    if (!gradable.length) {
      panel.append(Empty('Nothing to submit', 'Every raw card is already at the grader.', 'cards'));
      return panel;
    }

    const list = h('div', { style: { maxHeight: '520px', overflowY: 'auto' } });
    for (const card of sorted.slice(0, 40)) {
      const on = selection.has(card.uid);
      const row = h('div', {
        class: 'sell-row', style: { cursor: 'pointer', background: on ? 'rgba(78,168,255,.10)' : '' },
        onclick: () => {
          if (selection.has(card.uid)) selection.delete(card.uid); else selection.add(card.uid);
          AudioSystem.play('click');
          render();
        },
      },
      h('div', { style: { width: '40px', flex: 'none' } }, CardView(card, { size: 'fluid', tilt: false, effects: false })),
      h('div', { class: 'info truncate' },
        h('div', { class: 'nm truncate' }, card.player),
        h('div', { class: 'tr truncate' }, CardSystem.label(card)),
      ),
      h('div', { class: 'qt' },
        h('b', {}, money(CardSystem.bookValue(card))),
        h('span', {}, `AGA 10: ${money(card.values['10'])}`),
      ),
      h('div', { style: { width: '18px', color: on ? 'var(--blue)' : 'var(--text-faint)' } }, on ? Icon('check') : Icon('plus')),
      );
      list.append(row);
    }
    panel.append(list);

    const picked = [...selection].map((u) => InventorySystem.find(u)).filter(Boolean);
    panel.append(h('div', { style: { padding: 'var(--s-4) var(--s-5)', borderTop: '1px solid var(--hairline)' } },
      h('div', { class: 'row' },
        h('span', { class: 'muted' }, `${picked.length} selected`),
        h('div', { class: 'spacer' }),
        picked.length ? Button('Clear', { size: 'sm', variant: 'ghost', onClick: () => { selection.clear(); render(); } }) : null,
      ),
      h('div', { style: { marginTop: 'var(--s-3)' } },
        Button('Submit to Apex', {
          variant: 'primary', block: true, icon: 'shield', disabled: !picked.length,
          onClick: () => openSubmitDialog(picked, { onDone: () => { selection.clear(); render(); refresh(); } }),
        })),
    ));
    return panel;
  }

  /* --------------------------------------------------------- reveal flow */

  async function openSubmission(sub) {
    const graded = GradingSystem.collect(sub.id);
    if (!graded?.length) { render(); return; }
    ProgressionSystem.awardForGrades(graded);
    refresh();
    await revealCeremony(graded);
    render();
    refresh();
  }

  async function openAll(subs) {
    const all = [];
    for (const sub of subs) {
      const g = GradingSystem.collect(sub.id);
      if (g) all.push(...g);
    }
    if (!all.length) { render(); return; }
    ProgressionSystem.awardForGrades(all);
    refresh();
    await revealCeremony(all);
    render();
    refresh();
  }

  function revealCeremony(graded) {
    return new Promise((resolve) => {
      let i = 0;
      const body = h('div', { class: 'grade-reveal' });
      const modal = Modal({
        title: 'Grades are in',
        width: 620,
        dismissable: false,
        body,
        actions: [],
      });

      const step = async () => {
        if (i >= graded.length) { modal.close(); resolve(); return; }
        const g = graded[i];
        i += 1;
        clear(body);

        const gem = g.grade === 10;
        AudioSystem.play('gradeReveal');
        body.append(
          h('div', { class: 'eyebrow' }, `Card ${i} of ${graded.length}`),
          h('div', { class: 'muted' }, `${g.card.player} · ${CardSystem.label(g.card)}`),
        );
        await wait(AnimationSystem.ms(520));

        const slab = Slab(g.card, { size: 'lg' });
        body.append(h('div', { style: { width: 'min(300px, 60vw)' } }, slab));
        await wait(AnimationSystem.ms(420));

        AudioSystem.play(gem ? 'gem' : 'gradeReveal');
        if (gem) burst(body, { count: 70, tier: 'oneofone', origin: [0.5, 0.4], power: 1.3 });
        else if (g.grade === 9) burst(body, { count: 24, tier: 'legendary', origin: [0.5, 0.4], power: 0.9 });

        const profit = g.after - g.before - g.feeShare;
        body.append(
          h('div', { class: ['grade-big', gem && 'is-gem'] }, `AGA ${g.grade}`),
          h('div', { class: 'eyebrow' }, GradingSystem.gradeName(g.grade)),
          h('div', { class: 'pl-grid' },
            cell('Raw value', money(g.before)),
            cell('Grading cost', money(g.feeShare)),
            cell(`AGA ${g.grade} value`, money(g.after)),
            cell('Result', money(profit, { sign: true }), profit >= 0 ? 'var(--green)' : 'var(--red)'),
          ),
          h('div', { class: 'cond-grid', style: { width: 'min(560px, 90vw)' } },
            ...Object.entries(GradingSystem.subLabels()).map(([k, label]) =>
              h('div', { class: 'cond' }, h('div', { class: 'k' }, label.toUpperCase()), h('div', { class: 'v' }, String(g.card.grade.subs[k])))),
          ),
          h('div', { class: 'row', style: { justifyContent: 'center', marginTop: 'var(--s-3)' } },
            Button(i >= graded.length ? 'Done' : 'Next slab', { variant: 'gold', onClick: step }),
          ),
        );

        if (gem) {
          toast({ title: 'GEM MINT 10', note: `${g.card.player} · ${money(g.after)}`, tone: 'gold', icon: 'star', ttl: 6000 });
        }
      };

      const cell = (k, v, color) => h('div', { class: 'pl-cell' },
        h('div', { class: 'k' }, k.toUpperCase()),
        h('div', { class: 'v', style: color ? { color } : undefined }, v));

      step();
    });
  }

  render();
  return { destroy() { clearInterval(timer); } };
}
