/** Grading submission dialog: tier choice, fees, turnaround and the risk picture. */
import { h, clear } from '../../core/dom.js';
import { money, num, relativeTime } from '../../core/format.js';
import { S } from '../../core/store.js';
import { GradingSystem } from '../../systems/GradingSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { EconomySystem } from '../../systems/EconomySystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { Button, Modal, KV, toast, Bar } from './ui.js';
import { CardView } from './CardView.js';

export function openSubmitDialog(cards, { onDone } = {}) {
  let tierId = 'express';
  const body = h('div', { class: 'stack' });

  const render = () => {
    clear(body);
    const previews = cards.map((c) => GradingSystem.preview(c, tierId));
    const rawTotal = previews.reduce((a, p) => a + p.raw, 0);
    const feeTotal = GradingSystem.tier(tierId).fee * cards.length;
    const tenTotal = previews.reduce((a, p) => a + p.ten, 0);
    const nineTotal = previews.reduce((a, p) => a + p.nine, 0);
    const affordable = EconomySystem.canAfford(feeTotal);

    body.append(
      h('div', { class: 'summary-cards', style: { justifyContent: 'flex-start' } },
        ...cards.slice(0, 6).map((c) => h('div', { style: { width: '92px' } }, CardView(c, { size: 'fluid', tilt: false, effects: false }))),
        cards.length > 6 ? h('div', { class: 'muted', style: { alignSelf: 'center' } }, `+${cards.length - 6} more`) : null,
      ),
      h('div', { class: 'eyebrow', style: { marginTop: 'var(--s-4)' } }, 'Service level'),
      h('div', { class: 'stack' }, ...GradingSystem.tiers().map((t) => {
        const eligible = cards.every((c) => t.maxValue === null || CardSystem.bookValue(c) <= t.maxValue);
        return h('button', {
          class: ['panel', 'panel-pad'],
          type: 'button',
          disabled: !eligible,
          style: {
            textAlign: 'left', cursor: eligible ? 'pointer' : 'not-allowed',
            opacity: eligible ? '1' : '.45',
            borderColor: tierId === t.id ? 'var(--blue)' : 'var(--hairline)',
            background: tierId === t.id ? 'rgba(78,168,255,.10)' : 'var(--surface)',
          },
          onclick: () => { if (eligible) { tierId = t.id; AudioSystem.play('click'); render(); } },
        },
        h('div', { class: 'row' },
          h('div', {},
            h('div', { style: { fontFamily: 'var(--f-display)' } }, t.label),
            h('div', { class: 'muted', style: { fontSize: 'var(--t-sm)' } }, t.blurb),
          ),
          h('div', { class: 'spacer' }),
          h('div', { style: { textAlign: 'right' } },
            h('div', { style: { fontFamily: 'var(--f-display)', color: 'var(--gold-lite)' } }, money(t.fee)),
            h('div', { class: 'muted', style: { fontSize: 'var(--t-xs)' } }, relativeTime(GradingSystem.turnaroundMs(t.id))),
          ),
        ),
        !eligible ? h('div', { class: 'muted', style: { fontSize: 'var(--t-xs)', marginTop: '6px' } }, `Declared value above ${money(t.maxValue)} needs a higher tier.`) : null,
        );
      })),
      h('div', { class: 'divider' }),
      KV([
        ['Cards', num(cards.length)],
        ['Raw value today', money(rawTotal)],
        ['Grading fees', money(feeTotal), 'neg'],
        ['If everything gems', money(tenTotal - rawTotal - feeTotal, { sign: true }), 'pos'],
        ['If everything grades 9', money(nineTotal - rawTotal - feeTotal, { sign: true })],
        ['Balance after fees', money(S().cash - feeTotal), affordable ? '' : 'neg'],
      ]),
      h('p', { class: 'muted', style: { fontSize: 'var(--t-xs)' } },
        'Apex Grading Authority is a fictional service. Grades depend on hidden centering, corner, edge and surface condition rolled when the card was pulled, plus grader variance. A perfect card is never a guaranteed ten.'),
    );
  };

  render();

  const modal = Modal({
    title: `Submit ${cards.length} card${cards.length > 1 ? 's' : ''} to Apex`,
    width: 680,
    body,
    actions: [
      h('div', { class: 'spacer' }),
      Button('Cancel', { variant: 'ghost', onClick: () => modal.close() }),
      Button('Submit', {
        variant: 'primary', icon: 'shield', sound: 'submit',
        onClick: () => {
          const sub = GradingSystem.submit(cards.map((c) => c.uid), tierId);
          modal.close();
          if (!sub) { toast({ title: 'Submission failed', note: 'Not enough cash for the fees.', tone: 'bad', icon: 'error' }); return; }
          toast({
            title: 'Off to the grader',
            note: `${sub.cardUids.length} card(s) · back in ${relativeTime(sub.readyAt - Date.now())}`,
            tone: 'info', icon: 'shield',
          });
          onDone?.();
        },
      }),
    ],
  });
  return modal;
}
