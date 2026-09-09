/**
 * Break Room: the opening ceremony.
 *
 * sealed box -> break the seal -> choose a pack -> rip -> reveal each card with
 * drama proportional to its rarity -> pack wrap-up -> box wrap-up.
 */
import { h, clear, wait } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, num, compactMoney } from '../../core/format.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { Data } from '../../systems/DataService.js';
import { BreakSystem } from '../../systems/BreakSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { AnimationSystem } from '../../systems/AnimationSystem.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { burst } from '../../effects/particles.js';
import { Button, Stat, Icon, Empty, Chip, toast } from '../components/ui.js';
import { CardView, CardTile, preloadCards } from '../components/CardView.js';

export default function Opening({ mount, params, navigate, refresh }) {
  let vaultId = params.vaultId ?? BreakSystem.next()?.id ?? null;
  let busy = false;
  let cancelFx = null;

  const stage = h('div', { class: 'break-stage' });
  const fx = h('div', { class: 'stage-fx' });
  const rays = h('div', { class: 'fx-rays' });
  fx.append(rays);
  stage.append(fx);
  mount.append(stage);
  Assets.mount(rays, AssetKeys.fx('rays'));

  const body = h('div', { style: { position: 'relative', zIndex: '5', width: '100%' } });
  stage.append(body);

  const setStage = (...nodes) => { clear(body); body.append(...nodes); };

  /* ------------------------------------------------------------- states */

  function renderIdle() {
    const sealed = BreakSystem.sealed();
    if (sealed.length) { vaultId = sealed[0].id; renderBox(); return; }
    setStage(h('div', { class: 'stage-copy' },
      Empty('Nothing sealed', 'The vault is empty. Every product in the shop is hobby configuration.', 'box'),
      Button('Go to the hobby shop', { variant: 'gold', icon: 'box', onClick: () => navigate('store') }),
    ));
  }

  function renderBox() {
    const entry = BreakSystem.find(vaultId);
    if (!entry) return renderIdle();
    const box = Data.box(entry.boxId);
    if (entry.opened) return renderPacks();

    const boxEl = h('div', { class: 'sealed-box', role: 'button', tabindex: '0', title: 'Break the seal' });
    Assets.mount(boxEl, AssetKeys.box(box.id), { preserveAspectRatio: 'xMidYMid meet' });

    const open = async () => {
      if (busy) return;
      busy = true;
      AudioSystem.play('boxOpen');
      boxEl.classList.add('is-shaking');
      await wait(AnimationSystem.ms(540));
      boxEl.classList.add('is-gone');
      AnimationSystem.shake(stage, 8, 480);
      burst(stage, { count: 30, tier: 'legendary', origin: [0.5, 0.5], power: 0.9 });
      await wait(AnimationSystem.ms(560));
      BreakSystem.breakSeal(vaultId);
      busy = false;
      refresh();
      renderPacks();
    };
    boxEl.addEventListener('click', open);
    boxEl.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); } });

    setStage(h('div', { style: { display: 'grid', justifyItems: 'center', gap: 'var(--s-6)' } },
      h('div', { class: 'stage-copy' },
        h('div', { class: 'eyebrow' }, `${box.year} · ${box.manufacturer} · Hobby`),
        h('div', { class: 'stage-title' }, box.name),
        h('div', { class: 'stage-note' }, `${box.packs} packs, ${box.cardsPerPack} cards per pack. ${box.guarantees[0]}.`),
      ),
      boxEl,
      Button('Break the seal', { variant: 'gold', size: 'lg', icon: 'sparkle', onClick: open }),
    ));
  }

  function renderPacks() {
    const entry = BreakSystem.find(vaultId);
    if (!entry) return renderIdle();
    const box = Data.box(entry.boxId);
    const remaining = entry.packs.filter((p) => !p.opened).length;

    if (!remaining) return renderBoxSummary();

    const fan = h('div', { class: 'pack-fan' });
    entry.packs.forEach((pack, i) => {
      const el = h('div', {
        class: ['pack', pack.opened && 'is-opened'],
        style: { animationDelay: `${i * 26}ms` },
        role: pack.opened ? undefined : 'button',
        tabindex: pack.opened ? undefined : '0',
        title: pack.opened ? 'Already opened' : `Pack ${i + 1}`,
      }, h('span', { class: 'pack-no' }, String(i + 1)));
      const holder = h('div', {});
      el.prepend(holder);
      Assets.mount(holder, AssetKeys.pack(box.id), { preserveAspectRatio: 'xMidYMid meet' });
      if (!pack.opened) {
        const go = () => ripPack(i, el);
        el.addEventListener('click', go);
        el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); } });
      }
      fan.append(el);
    });

    setStage(h('div', { style: { display: 'grid', justifyItems: 'center', gap: 'var(--s-4)', width: '100%' } },
      h('div', { class: 'stage-copy' },
        h('div', { class: 'eyebrow' }, box.name),
        h('div', { class: 'stage-title' }, 'Pick a pack'),
        h('div', { class: 'stage-note' }, `${remaining} of ${entry.packs.length} packs still sealed.`),
      ),
      fan,
      h('div', { class: 'row' },
        Button('Rip the next pack', { variant: 'gold', icon: 'sparkle', onClick: () => {
          const idx = entry.packs.findIndex((p) => !p.opened);
          if (idx >= 0) ripPack(idx, fan.children[idx]);
        } }),
        remaining > 1 ? Button('Rip everything', { variant: 'ghost', icon: 'bolt', onClick: () => ripAll() }) : null,
      ),
    ));
  }

  async function ripPack(index, el) {
    if (busy) return;
    busy = true;
    AudioSystem.play('packRip');
    el?.classList.add('is-ripping');
    await wait(AnimationSystem.ms(520));
    const cards = BreakSystem.openPack(vaultId, index);
    busy = false;
    refresh();
    if (!cards) return renderPacks();
    await preloadCards(cards);
    revealSequence(cards, index);
  }

  async function ripAll() {
    if (busy) return;
    busy = true;
    const entry = BreakSystem.find(vaultId);
    const all = [];
    for (const pack of entry.packs) {
      if (pack.opened) continue;
      const cards = BreakSystem.openPack(vaultId, pack.index);
      if (cards) all.push(...cards);
      AudioSystem.play('packRip', { rate: 1.4 });
      await wait(60);
    }
    busy = false;
    refresh();
    const best = all.reduce((b, c) => (!b || c.baseValue > b.baseValue ? c : b), null);
    if (best) AudioSystem.reveal(best, best.rarity);
    toast({ title: 'Box emptied', note: `${all.length} cards · ${money(all.reduce((a, c) => a + c.baseValue, 0))}`, tone: 'gold', icon: 'box' });
    renderBoxSummary();
  }

  /* ------------------------------------------------------------ reveals */

  function revealSequence(cards, packIndex) {
    let i = 0;
    const tray = h('div', { class: 'reveal-tray' });
    const holder = h('div', { class: 'reveal-card' });
    const banner = h('div', { class: 'reveal-banner' });
    const info = h('div', { class: 'reveal-info' });
    const progress = h('div', { class: 'reveal-progress' });
    const controls = h('div', { class: 'row' });

    const skip = Button('Reveal the rest', {
      variant: 'ghost', icon: 'bolt',
      onClick: async () => {
        skip.disabled = true;
        while (i < cards.length) { await showCard(true); }
      },
    });
    const next = Button('Next card', { variant: 'primary', icon: 'chevron', onClick: () => showCard() });
    controls.append(next, skip);

    setStage(h('div', { class: 'reveal-stage' },
      h('div', { style: { position: 'relative' } }, banner, holder),
      info, progress, controls, tray,
    ));

    const onKey = (e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); showCard(); } };
    document.addEventListener('keydown', onKey);

    async function showCard(fast = false) {
      if (busy || i >= cards.length) {
        if (i >= cards.length && !busy) finish();
        return;
      }
      busy = true;
      const card = cards[i];
      i += 1;
      const rarity = Data.rarity(card.rarity);
      const cho = AnimationSystem.choreography(card.rarity, card);
      const speed = fast ? 0.25 : 1;

      clear(holder);
      banner.classList.remove('is-on');
      banner.textContent = '';
      progress.textContent = `Card ${i} of ${cards.length}`;
      clear(info);

      holder.style.setProperty('--rc', rarity.color);
      banner.style.setProperty('--rc', rarity.color);

      // build-up
      if (cho.build && !fast) {
        rays.classList.toggle('is-on', cho.rays);
        rays.classList.toggle('is-spin', card.rarity === 'oneofone');
        if (cho.banner) { banner.textContent = cho.banner; banner.classList.add('is-on'); }
        if (cho.takeover) await AnimationSystem.flash(stage, { peak: 0.7, duration: 420 });
        if (cho.shake) AnimationSystem.shake(stage, cho.shake, cho.build);
        AudioSystem.play(cho.takeover ? 'whoosh' : 'cardFlip', { rate: 0.9 });
        await wait(cho.build);
      } else {
        rays.classList.remove('is-on');
      }

      const view = CardView(card, { size: 'fluid', faceDown: true });
      holder.append(view);
      holder.classList.remove('is-out');
      holder.classList.add('is-in');
      await wait(AnimationSystem.ms(140) * speed);

      AudioSystem.play('cardFlip');
      view.flip(false);
      await wait(cho.flip * speed);

      AudioSystem.reveal(card, card.rarity);
      if (cho.particles && !fast) {
        cancelFx?.();
        cancelFx = burst(stage, { count: cho.particles, tier: card.rarity, origin: [0.5, 0.42], power: 1 + cho.glow });
      }

      const value = card.baseValue;
      info.append(
        h('div', { class: 'rn' }, card.player),
        h('div', { class: 'rt' }, `${card.year} ${card.set} · ${CardSystem.label(card)}`),
        h('div', { class: 'rv' }, money(value)),
      );

      const chip = CardView(card, { size: 'fluid', tilt: false, effects: false });
      const trayCell = h('div', { style: { width: '62px' } }, chip);
      tray.append(trayCell);

      await wait(Math.max(120, cho.settle * speed));
      busy = false;
      next.disabled = i >= cards.length;
      if (i >= cards.length) { next.textContent = 'Done'; setTimeout(finish, fast ? 60 : 420); }
    }

    function finish() {
      document.removeEventListener('keydown', onKey);
      rays.classList.remove('is-on');
      renderPackSummary(cards, packIndex);
    }

    showCard();
  }

  function renderPackSummary(cards, packIndex) {
    const entry = BreakSystem.find(vaultId);
    const value = cards.reduce((a, c) => a + c.baseValue, 0);
    const best = cards.reduce((b, c) => (!b || c.baseValue > b.baseValue ? c : b), null);
    const remaining = entry ? entry.packs.filter((p) => !p.opened).length : 0;

    setStage(h('div', { style: { display: 'grid', justifyItems: 'center', gap: 'var(--s-5)', width: '100%' } },
      h('div', { class: 'stage-copy' },
        h('div', { class: 'eyebrow' }, `Pack ${packIndex + 1} results`),
        h('div', { class: 'stage-title' }, best ? `${best.player} led the pack` : 'Pack opened'),
      ),
      h('div', { class: 'summary-grid', style: { width: 'min(760px, 92vw)' } },
        Stat('Pack value', money(value), { accent: 'var(--gold)', gold: true }),
        Stat('Cards', num(cards.length), { accent: 'var(--blue)' }),
        Stat('Hits', num(cards.filter((c) => c.hitType).length), { accent: 'var(--violet)' }),
        Stat('Numbered', num(cards.filter((c) => c.serial).length), { accent: 'var(--green)' }),
      ),
      h('div', { class: 'summary-cards' }, ...cards.slice(-6).reverse().map((c) => h('div', { style: { width: '110px' } }, CardView(c, { size: 'fluid' })))),
      h('div', { class: 'row' },
        remaining ? Button('Next pack', { variant: 'gold', icon: 'sparkle', onClick: () => renderPacks() }) : Button('Box results', { variant: 'gold', onClick: () => renderBoxSummary() }),
        Button('Back to packs', { variant: 'ghost', onClick: () => renderPacks() }),
      ),
    ));
  }

  function renderBoxSummary() {
    const sum = BreakSystem.summary(vaultId);
    if (!sum) return renderIdle();
    const profitClass = sum.profit >= 0 ? 'pos' : 'neg';
    const top = [...sum.cards].sort((a, b) => b.baseValue - a.baseValue).slice(0, 8);

    setStage(h('div', { style: { display: 'grid', justifyItems: 'center', gap: 'var(--s-5)', width: '100%' } },
      h('div', { class: 'stage-copy' },
        h('div', { class: 'eyebrow' }, sum.box.name),
        h('div', { class: 'stage-title' }, sum.entry.caseHit ? 'Case hit in the box' : 'Box complete'),
        h('div', { class: 'stage-note' }, `${sum.packsOpened} packs opened · ${sum.cards.length} cards filed to the collection.`),
      ),
      h('div', { class: 'summary-grid', style: { width: 'min(860px, 92vw)' } },
        Stat('Box cost', money(sum.entry.price), { accent: 'var(--red)' }),
        Stat('Pulled value', money(sum.value), { accent: 'var(--gold)', gold: true }),
        Stat('Result', money(sum.profit, { sign: true }), { accent: sum.profit >= 0 ? 'var(--green)' : 'var(--red)' }),
        Stat('Hits', num(sum.hits.length), { accent: 'var(--violet)', note: `${sum.numbered.length} numbered` }),
      ),
      h('div', { class: 'summary-cards' }, ...top.map((c) => h('div', { style: { width: '124px' } },
        CardView(c, { size: 'fluid' }),
        h('div', { class: 'card-cap' }, h('b', { class: 'truncate' }, c.player), h('span', { class: 'val' }, money(c.baseValue)))))),
      h('div', { class: 'row' },
        Button('Buy another box', { variant: 'gold', icon: 'box', onClick: () => navigate('store') }),
        Button('Sell the extras', { variant: 'primary', icon: 'sell', onClick: () => navigate('market') }),
        Button('View collection', { variant: 'ghost', icon: 'cards', onClick: () => navigate('collection') }),
      ),
    ));
  }

  /* --------------------------------------------------------------- start */
  if (!vaultId) renderIdle();
  else {
    const entry = BreakSystem.find(vaultId);
    if (!entry) renderIdle();
    else if (entry.finished) renderBoxSummary();
    else if (entry.opened) renderPacks();
    else renderBox();
  }

  return { destroy() { cancelFx?.(); } };
}
