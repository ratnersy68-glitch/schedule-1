/** Full card detail: large art, provenance, condition, value and the sell/grade actions. */
import { h, clear } from '../../core/dom.js';
import { money, num, timeAgo, pct } from '../../core/format.js';
import { Data } from '../../systems/DataService.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { MarketSystem } from '../../systems/MarketSystem.js';
import { GradingSystem } from '../../systems/GradingSystem.js';
import { InventorySystem } from '../../systems/InventorySystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { Button, Modal, Chip, KV, toast } from './ui.js';
import { CardView } from './CardView.js';
import { Slab } from './Slab.js';
import { openSubmitDialog } from './SubmitDialog.js';

export function openInspector(card, { onChange } = {}) {
  const rarity = Data.rarity(card.rarity);
  const quote = MarketSystem.quote(card);
  const pending = InventorySystem.isPending(card.uid);
  const idx = MarketSystem.index(card.playerId);
  const anchor = MarketSystem.anchorFor(Data.player(card.playerId));

  const art = h('div', { class: 'inspect-art' });
  art.append(card.grade ? Slab(card, { size: 'lg', tilt: true }) : CardView(card, { size: 'fluid', tilt: true }));
  art.append(h('div', { class: 'row', style: { justifyContent: 'center', flexWrap: 'wrap' } },
    Chip(rarity.label, { color: rarity.color, dot: true }),
    card.rookie ? Chip('Rookie', { color: 'var(--gold)' }) : null,
    card.autograph ? Chip('Autograph', { color: 'var(--r-epic)' }) : null,
    card.memorabilia ? Chip('Memorabilia', { color: 'var(--r-rare)' }) : null,
    card.serial ? Chip(`${card.serial.num}/${card.serial.run}`, { color: rarity.color }) : null,
  ));

  const cond = card.grade
    ? h('div', { class: 'cond-grid' }, ...Object.entries(GradingSystem.subLabels()).map(([k, label]) =>
      h('div', { class: 'cond' }, h('div', { class: 'k' }, label.toUpperCase()), h('div', { class: 'v' }, String(card.grade.subs[k])))))
    : h('p', { class: 'muted' }, 'Condition is sealed until the card is graded. Apex will report centering, corners, edges and surface with the slab.');

  const values = card.values;
  const detail = h('div', { class: 'stack' },
    h('div', {},
      h('div', { class: 'eyebrow' }, `${card.year} ${card.set}`),
      h('h3', { style: { fontFamily: 'var(--f-display)', fontSize: 'var(--t-2xl)', lineHeight: '1.05' } }, card.player),
      h('div', { class: 'muted' }, `${card.position} · ${card.team} · #${card.cardNumber}`),
    ),
    KV([
      ['Treatment', CardSystem.label(card)],
      ['Print run', card.serial ? `${card.serial.num} of ${card.serial.run}` : 'Unnumbered'],
      ['Pulled', `${timeAgo(card.pulledAt)} from ${Data.box(card.pulledFrom).shortName}`],
      ['Book value', money(CardSystem.bookValue(card))],
      ['Player index', `${idx.toFixed(2)}x`, idx >= anchor ? 'pos' : 'neg'],
      ['Market offer', money(quote.net), 'pos'],
      card.grade ? ['Grade', `${GradingSystem.gradeName(card.grade.grade)} ${card.grade.grade}`] : null,
      card.grade ? ['Certification', card.grade.cert] : null,
    ].filter(Boolean)),
    h('div', { class: 'divider' }),
    h('div', { class: 'eyebrow' }, card.grade ? 'Grader report' : 'Grading upside'),
    cond,
    !card.grade ? h('div', { class: 'cond-grid', style: { marginTop: 'var(--s-3)' } },
      ...[10, 9, 8, 7].map((g) => h('div', { class: 'cond' },
        h('div', { class: 'k' }, `AGA ${g}`),
        h('div', { class: 'v', style: { color: g === 10 ? 'var(--gold-lite)' : '' } }, money(values[String(g)])))),
    ) : null,
  );

  const modal = Modal({
    title: 'Card detail',
    width: 900,
    body: h('div', { class: 'inspect' }, art, detail),
    actions: [
      h('div', { class: 'spacer' }),
      Button('Close', { variant: 'ghost', onClick: () => modal.close() }),
      !card.grade && !pending
        ? Button('Send to Apex', {
          variant: 'primary', icon: 'shield',
          onClick: () => { modal.close(); openSubmitDialog([card], { onDone: onChange }); },
        })
        : null,
      pending ? Button('At the grader', { disabled: true, icon: 'clock' }) : null,
      Button(`Sell for ${money(quote.net)}`, {
        variant: 'gold', icon: 'sell', sound: 'sell',
        onClick: () => {
          const result = MarketSystem.sell(card.uid);
          modal.close();
          if (result) {
            AudioSystem.play('cash');
            toast({ title: 'Sold', note: `${card.player} · ${money(result.quote.net)} after fees`, tone: 'gold', icon: 'cash' });
            onChange?.();
          }
        },
      }),
    ].filter(Boolean),
  });
  return modal;
}
