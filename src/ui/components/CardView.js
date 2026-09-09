/**
 * CardView - composites one trading card from manifest artwork plus live data.
 *
 * Layer order mirrors how a real card is printed:
 *   franchise field -> template art -> insert art -> athlete -> template frame
 *   -> parallel finish -> relic/autograph -> typography -> specular glass
 *
 * Art arrives through the AssetRegistry, so every layer can be replaced by a
 * commissioned file without touching this module.
 */
import { h, append } from '../../core/dom.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { Data } from '../../systems/DataService.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { teamTokens, isLight } from '../../core/color.js';
import { signatureSvg } from './signature.js';
import { patchSvg } from './patch.js';

const FOIL_OF = (parallelId) => Data.parallel(parallelId).foil;

/** Keys a card needs, so a screen can preload before first paint. */
export function cardAssetKeys(card) {
  const keys = [
    AssetKeys.frameBg(card.template), AssetKeys.frameFg(card.template),
    AssetKeys.pose(card.pose), AssetKeys.team(card.teamId),
    AssetKeys.league(card.sport), AssetKeys.brand(card.setId),
    AssetKeys.cardBack(card.sport),
  ];
  const foil = FOIL_OF(card.parallel);
  if (foil !== 'none') keys.push(AssetKeys.foil(foil));
  if (card.insertSet) keys.push(AssetKeys.insert(Data.insertSet(card.insertSet).art));
  return keys;
}

export function preloadCards(cards) {
  const keys = new Set();
  for (const c of cards) for (const k of cardAssetKeys(c)) keys.add(k);
  return Assets.preload([...keys]);
}

/**
 * @param card                 card instance
 * @param options.size         css size class: xs | sm | md | lg | xl | fluid
 * @param options.faceDown     start showing the back
 * @param options.tilt         pointer parallax
 * @param options.effects      allow rarity animation
 */
export function CardView(card, options = {}) {
  const { size = 'md', faceDown = false, tilt = true, effects = true } = options;
  const team = Data.team(card.teamId);
  const parallel = Data.parallel(card.parallel);
  const rarity = Data.rarity(card.rarity);
  const foil = FOIL_OF(card.parallel);

  const product = Data.box(card.setId);
  const pal = product.palette;
  const style = {
    ...teamTokens(team),
    '--ps': pal.accent,
    '--pf': pal.foil,
    '--pi': pal.ink,
    '--pb': pal.base,
    '--rc': rarity.color,
  };
  if (parallel.id !== 'none' && foil === 'tint') {
    style['--parallel-color'] = parallel.color;
    style['--parallel-strength'] = '0.72';
  }

  const el = h('div', {
    class: ['card', size !== 'fluid' && `card-${size}`, faceDown && 'is-flipped', !tilt && 'no-tilt'],
    style,
    dataset: {
      foil,
      effect: effects ? rarity.effect : 'none',
      rarity: card.rarity,
      template: card.template,
      ink: isLight(team.colors.primary) ? 'dark' : 'light',
      uid: card.uid,
      ...(card.memorabilia ? { relic: '1' } : {}),
      ...(card.autograph ? { auto: '1' } : {}),
    },
  });

  const front = h('div', { class: 'card-face card-front-face' });
  const back = h('div', { class: 'card-face card-back-face' });
  const inner = h('div', { class: 'card-inner' }, front, back);
  el.append(inner);

  const layer = (cls) => { const d = h('div', { class: `card-l ${cls}` }); front.append(d); return d; };

  layer('l-field');
  const bgLayer = layer('l-frame-bg');
  const insertLayer = card.insertSet ? layer('l-insert') : null;
  const artLayer = layer('l-art');
  const fgLayer = layer('l-frame-fg');
  const tintLayer = foil === 'tint' ? layer('l-tint') : null;
  const foilLayer = foil !== 'none' ? layer('l-foil') : null;
  const extras = layer('l-relic');
  const type = layer('l-type');
  layer('l-gloss');

  /* --- typography ------------------------------------------------------- */
  const nameLen = card.player.length;
  append(type, [
    h('div', { class: 'c-crest' }),
    h('div', { class: 'c-league' }),
    h('div', { class: 'c-brand' }),
    card.rookie ? h('div', { class: 'c-rookie' }, 'RC') : null,
    card.serial ? h('div', { class: 'c-serial' }, `${card.serial.num}/${card.serial.run}`) : null,
    h('div', { class: ['c-name', nameLen > 17 && 'is-xlong', nameLen > 13 && nameLen <= 17 && 'is-long'] }, card.player),
    h('div', { class: 'c-meta' }, `${card.position} · ${team.city} ${team.nickname}`),
    h('div', { class: 'c-treat' }, CardSystem.label(card).toUpperCase()),
    h('div', { class: 'c-num' }, `#${card.cardNumber}`),
  ]);

  if (card.memorabilia) {
    const prime = card.hitType === 'patchAuto' || card.hitType === 'booklet';
    extras.append(h('div', { class: 'c-patch', html: patchSvg(card, team.colors, { prime }) }));
  }
  if (card.autograph) {
    extras.append(h('div', { class: 'c-auto', html: signatureSvg(card.player, { dual: card.hitType === 'dualAuto' }) }));
  }

  /* --- art -------------------------------------------------------------- */
  const mount = async () => {
    await Promise.all([
      Assets.mount(bgLayer, AssetKeys.frameBg(card.template), { preserveAspectRatio: 'xMidYMid slice' }),
      Assets.mount(artLayer, AssetKeys.pose(card.pose), { preserveAspectRatio: 'xMidYMax meet' }),
      Assets.mount(fgLayer, AssetKeys.frameFg(card.template), { preserveAspectRatio: 'xMidYMid slice' }),
      insertLayer && Assets.mount(insertLayer, AssetKeys.insert(Data.insertSet(card.insertSet).art), { preserveAspectRatio: 'xMidYMid slice' }),
      foilLayer && Assets.mount(foilLayer, AssetKeys.foil(foil), { preserveAspectRatio: 'xMidYMid slice' }),
      Assets.mount(type.querySelector('.c-crest'), AssetKeys.team(card.teamId)),
      Assets.mount(type.querySelector('.c-league'), AssetKeys.league(card.sport)),
      Assets.mount(type.querySelector('.c-brand'), AssetKeys.brand(card.setId)),
      Assets.mount(back, AssetKeys.cardBack(card.sport), { preserveAspectRatio: 'xMidYMid slice' }),
    ]);
    const num = artLayer.querySelector('.jersey-num');
    if (num) num.textContent = String(card.jersey ?? Data.player(card.playerId)?.jersey ?? 0);
  };
  mount();

  /* --- pointer parallax -------------------------------------------------- */
  if (tilt) {
    let raf = 0;
    const move = (e) => {
      const r = el.getBoundingClientRect();
      const mx = ((e.clientX - r.left) / r.width - 0.5) * 2;
      const my = ((e.clientY - r.top) / r.height - 0.5) * 2;
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        el.style.setProperty('--mx', mx.toFixed(3));
        el.style.setProperty('--my', my.toFixed(3));
      });
    };
    const reset = () => {
      cancelAnimationFrame(raf);
      el.style.setProperty('--mx', '0');
      el.style.setProperty('--my', '0');
    };
    el.addEventListener('pointermove', move);
    el.addEventListener('pointerleave', reset);
  }

  el.flip = (down) => el.classList.toggle('is-flipped', down ?? !el.classList.contains('is-flipped'));
  el.card = card;
  return el;
}

/** Small clickable collection tile with a caption. */
export function CardTile(card, { onClick, size = 'sm', caption = true, value } = {}) {
  const wrap = h('div', {
    class: 'card-tile',
    role: 'button',
    tabindex: '0',
    onclick: () => onClick?.(card),
    onkeydown: (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick?.(card); } },
  });
  wrap.append(CardView(card, { size, tilt: true }));
  if (caption) {
    wrap.append(h('div', { class: 'card-cap' },
      h('b', { class: 'truncate' }, card.player),
      h('span', { class: 'val' }, value ?? ''),
    ));
  }
  return wrap;
}
