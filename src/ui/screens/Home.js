/** Clubhouse: the dashboard. Balance, collection health, recent pulls, next steps. */
import { h, clear } from '../../core/dom.js';
import { S } from '../../core/store.js';
import { money, compactMoney, num, timeAgo, relativeTime } from '../../core/format.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { Data } from '../../systems/DataService.js';
import { EconomySystem } from '../../systems/EconomySystem.js';
import { InventorySystem } from '../../systems/InventorySystem.js';
import { MarketSystem } from '../../systems/MarketSystem.js';
import { GradingSystem } from '../../systems/GradingSystem.js';
import { ProgressionSystem } from '../../systems/ProgressionSystem.js';
import { ChallengeSystem } from '../../systems/ChallengeSystem.js';
import { CollectionSystem } from '../../systems/CollectionSystem.js';
import { BreakSystem } from '../../systems/BreakSystem.js';
import { CardSystem } from '../../systems/CardSystem.js';
import { Button, Stat, Bar, Icon, Chip, Empty, toast } from '../components/ui.js';
import { CardView, preloadCards } from '../components/CardView.js';
import { Sparkline } from '../components/Sparkline.js';
import { Slab } from '../components/Slab.js';

const greet = () => {
  const hour = new Date().getHours();
  if (hour < 5) return 'Still up';
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
};

export default function Home({ mount, navigate, refresh }) {
  const s = S();
  const jewel = InventorySystem.crownJewel();
  const summary = CollectionSystem.summary();
  const prog = ProgressionSystem.progress();
  const sealed = BreakSystem.sealed();
  const ready = GradingSystem.ready();
  const pending = GradingSystem.pending();

  const render = () => {
    clear(mount);

    /* ---------------------------------------------------------- hero */
    const hero = h('div', { class: 'home-hero' },
      h('section', { class: 'panel hero-panel' },
        h('div', {},
          h('div', { class: 'eyebrow' }, `${greet()}, collector`),
          h('h1', { class: 'hero-greet' }, s.collection.length ? 'The vault is filling up.' : 'Time to buy something sealed.'),
        ),
        h('p', { class: 'hero-line' }, heroLine(s, sealed, ready)),
        h('div', { class: 'hero-stats' },
          Stat('Balance', money(s.cash), { accent: 'var(--gold)', gold: true, note: EconomySystem.stipendAvailable() ? 'Daily credit available' : 'Daily credit claimed' }),
          Stat('Collection', compactMoney(summary.value), { accent: 'var(--blue)', note: `${num(summary.count)} cards` }),
          Stat('Lifetime profit', money(EconomySystem.profit(), { sign: true }), { accent: EconomySystem.profit() >= 0 ? 'var(--green)' : 'var(--red)', note: `${num(s.stats.boxesOpened)} box${s.stats.boxesOpened === 1 ? '' : 'es'} opened` }),
          Stat('Gem rate', s.stats.gemRate.graded ? `${Math.round((s.stats.gemRate.tens / s.stats.gemRate.graded) * 100)}%` : '--', { accent: 'var(--violet)', note: `${num(s.stats.gradedCount)} graded` }),
        ),
        progressStrip(prog),
        h('div', { class: 'hero-cta' },
          sealed.length
            ? Button(`Open ${Data.box(sealed[0].boxId).shortName}`, { variant: 'gold', icon: 'box', onClick: () => navigate('open') })
            : Button('Browse hobby boxes', { variant: 'gold', icon: 'box', onClick: () => navigate('store') }),
          ready.length ? Button(`Collect ${ready.length} grade${ready.length > 1 ? 's' : ''}`, { variant: 'primary', icon: 'shield', onClick: () => navigate('grading') }) : null,
          EconomySystem.stipendAvailable()
            ? Button('Claim daily credit', { icon: 'gift', onClick: () => {
              const amount = EconomySystem.claimDailyStipend();
              if (amount) { toast({ title: 'Daily credit claimed', note: money(amount), tone: 'gold', icon: 'cash' }); render(); refresh(); }
            } })
            : null,
        ),
      ),
      jewelPanel(jewel, navigate),
    );
    mount.append(hero);

    /* --------------------------------------------------------- grid */
    const grid = h('div', { class: 'home-grid' });
    grid.append(
      recentPulls(navigate),
      challengesPanel(render, refresh),
      featuredBoxes(navigate),
      gradingPanel(pending, ready, navigate),
      marketPanel(navigate),
    );
    mount.append(grid);
  };

  render();
  return { destroy() {} };
}

/** Level track plus what the next level unlocks - fills the hero and gives the player a target. */
function progressStrip(prog) {
  const next = ProgressionSystem.nextUnlock();
  const s = S();
  return h('div', { class: 'hero-progress' },
    h('div', { class: 'row' },
      h('span', { class: 'eyebrow' }, `Level ${prog.level}`),
      h('div', { class: 'spacer' }),
      h('span', { class: 'muted', style: { fontFamily: 'var(--f-mono)', fontSize: 'var(--t-xs)' } }, `${num(prog.into)} / ${num(prog.need)} XP`),
    ),
    Bar(prog.pct, { tone: 'gold' }),
    h('div', { class: 'row', style: { marginTop: 'var(--s-2)' } },
      Icon(next ? 'lock' : 'check'),
      h('span', { class: 'muted', style: { fontSize: 'var(--t-sm)' } },
        next
          ? `${next.name} unlocks at level ${next.unlockLevel}`
          : 'Every product on the shelf is unlocked.'),
      h('div', { class: 'spacer' }),
      h('span', { class: 'muted', style: { fontSize: 'var(--t-xs)' } },
        `${num(s.stats.packsOpened)} packs · ${num(s.stats.cardsPulled)} cards · ${num(s.stats.hits)} hits`),
    ),
  );
}

function heroLine(s, sealed, ready) {
  const bits = [];
  if (sealed.length) bits.push(`${sealed.length} sealed box${sealed.length > 1 ? 'es' : ''} waiting in the vault`);
  if (ready.length) bits.push(`${ready.length} grading submission${ready.length > 1 ? 's' : ''} back from Apex`);
  if (!bits.length) {
    return s.collection.length
      ? 'Nothing sealed on the shelf. The shop restocks every product, every day.'
      : 'Every product on the shelf is hobby configuration. No blasters, no hangers, no retail.';
  }
  return `${bits.join(' and ')}.`;
}

function jewelPanel(jewel, navigate) {
  const panel = h('section', { class: 'panel jewel' });
  if (!jewel) {
    panel.append(Empty('No cards yet', 'Your best pull will live here.', 'star'));
    return panel;
  }
  const value = CardSystem.bookValue(jewel) * MarketSystem.index(jewel.playerId);
  panel.append(
    h('div', { class: 'eyebrow' }, 'Crown jewel'),
    jewel.grade ? Slab(jewel, { size: 'md' }) : CardView(jewel, { size: 'fluid' }),
    h('div', {},
      h('div', { class: 'jewel-name' }, jewel.player),
      h('div', { class: 'jewel-meta' }, `${jewel.year} ${jewel.set} · ${CardSystem.label(jewel)}`),
    ),
    h('div', { class: 'jewel-value' }, money(value)),
    Button('Open collection', { size: 'sm', onClick: () => navigate('collection') }),
  );
  preloadCards([jewel]);
  return panel;
}

function recentPulls(navigate) {
  const pulls = S().pulls.slice(0, 8);
  const panel = h('section', { class: 'panel span-7' },
    h('div', { class: 'panel-head' },
      h('div', { class: 'panel-title' }, 'Recent pulls'),
      h('div', { class: 'spacer' }),
      Button('Collection', { size: 'sm', variant: 'ghost', onClick: () => navigate('collection') }),
    ),
  );
  if (!pulls.length) {
    panel.append(Empty('Nothing pulled yet', 'Open a pack and this fills up fast.', 'sparkle'));
    return panel;
  }
  const list = h('div', { class: 'pull-list' });
  for (const p of pulls) {
    const rarity = Data.rarity(p.rarity);
    const [who, what] = p.label.split(' - ');
    list.append(h('div', { class: 'pull-row' },
      h('i', { class: 'pip', style: { background: rarity.color, color: rarity.color } }),
      h('div', { class: 'truncate' },
        h('div', { class: 'who truncate' }, who),
        h('div', { class: 'what truncate' }, what),
      ),
      h('div', { class: 'val' }, money(p.value)),
      h('div', { class: 'when' }, timeAgo(p.ts)),
    ));
  }
  panel.append(list);
  return panel;
}

function challengesPanel(render, refresh) {
  const rows = ChallengeSystem.list();
  const panel = h('section', { class: 'panel span-5' },
    h('div', { class: 'panel-head' },
      h('div', { class: 'panel-title' }, 'Daily challenges'),
      h('div', { class: 'spacer' }),
      h('span', { class: 'section-note' }, 'Resets at midnight'),
    ),
  );
  for (const c of rows) {
    const row = h('div', { class: 'challenge' },
      h('div', { class: 'challenge-top' },
        h('span', { class: 'challenge-label' }, c.label),
        h('span', { class: 'challenge-reward' }, `${money(c.reward)} · ${c.xp} XP`),
      ),
      Bar(c.pct, { tone: c.complete ? 'gold' : '' }),
      h('div', { class: 'row' },
        h('span', { class: 'challenge-count' }, `${num(c.done)} / ${num(c.target)}`),
        h('div', { class: 'spacer' }),
        c.claimed
          ? Chip('Claimed', { color: 'var(--r-uncommon)' })
          : c.complete
            ? Button('Claim', { size: 'sm', variant: 'gold', onClick: () => { ChallengeSystem.claim(c.key); render(); refresh(); } })
            : null,
      ),
    );
    panel.append(row);
  }
  return panel;
}

function featuredBoxes(navigate) {
  const level = S().level;
  const affordable = Data.boxes
    .filter((b) => b.unlockLevel <= level)
    .sort((a, b) => b.price - a.price);
  const picks = [affordable.find((b) => b.price <= S().cash) ?? affordable.at(-1), ...affordable.slice(0, 2)]
    .filter(Boolean)
    .filter((b, i, arr) => arr.findIndex((x) => x.id === b.id) === i)
    .slice(0, 3);

  const panel = h('section', { class: 'panel span-7' },
    h('div', { class: 'panel-head' },
      h('div', { class: 'panel-title' }, 'On the shelf'),
      h('div', { class: 'spacer' }),
      Button('Hobby shop', { size: 'sm', variant: 'ghost', onClick: () => navigate('store') }),
    ),
  );
  const grid = h('div', { class: 'mini-boxes' });
  for (const box of picks) {
    const art = h('div', { class: 'box-art', style: { aspectRatio: '1 / 1', borderRadius: 'var(--r-md)' } });
    Assets.mount(art, AssetKeys.box(box.id), { preserveAspectRatio: 'xMidYMid meet' });
    grid.append(h('button', {
      class: 'box-card', type: 'button', style: { border: '1px solid var(--hairline)' },
      onclick: () => navigate('store', { focus: box.id }),
    },
    art,
    h('div', { class: 'box-body', style: { padding: 'var(--s-4)' } },
      h('div', { class: 'box-name', style: { fontSize: 'var(--t-md)' } }, box.shortName),
      h('div', { class: 'box-sub' }, `${box.sport} · ${box.packs} PACKS`),
      h('div', { class: 'box-price', style: { fontSize: 'var(--t-lg)' } }, money(box.price)),
    )));
  }
  panel.append(grid);
  return panel;
}

function gradingPanel(pending, ready, navigate) {
  const panel = h('section', { class: 'panel span-5' },
    h('div', { class: 'panel-head' },
      h('div', { class: 'panel-title' }, 'Apex Grading Authority'),
      h('div', { class: 'spacer' }),
      Button('Grading', { size: 'sm', variant: 'ghost', onClick: () => navigate('grading') }),
    ),
  );
  if (!pending.length) {
    panel.append(Empty('Nothing at the grader', 'Raw cards are worth less than slabs.', 'shield'));
    return panel;
  }
  for (const sub of pending.slice(0, 5)) {
    const isReady = Date.now() >= sub.readyAt;
    panel.append(h('div', { class: 'sub-row' },
      Icon('shield'),
      h('div', {},
        h('div', { class: 'nm', style: { fontWeight: 600, fontSize: 'var(--t-sm)' } }, `${sub.cardUids.length} card${sub.cardUids.length > 1 ? 's' : ''} · ${GradingSystem.tier(sub.tier).label}`),
        h('div', { class: 'what', style: { fontSize: 'var(--t-xs)', color: 'var(--text-mute)' } }, `Submitted ${timeAgo(sub.submittedAt)}`),
      ),
      h('div', { class: 'spacer' }),
      isReady
        ? h('span', { class: 'sub-ready' }, 'READY')
        : h('span', { class: 'sub-timer' }, relativeTime(sub.readyAt - Date.now())),
    ));
  }
  return panel;
}

function marketPanel(navigate) {
  const { up, down } = MarketSystem.movers(4);
  const panel = h('section', { class: 'panel span-12' },
    h('div', { class: 'panel-head' },
      h('div', { class: 'panel-title' }, 'Market movers'),
      h('div', { class: 'spacer' }),
      Button('Marketplace', { size: 'sm', variant: 'ghost', onClick: () => navigate('market') }),
    ),
  );
  const wrap = h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0' } });
  const col = (title, rows) => {
    const c = h('div', {});
    c.append(h('div', { style: { padding: 'var(--s-3) var(--s-5) 0' } }, h('div', { class: 'eyebrow' }, title)));
    for (const r of rows) {
      const team = Data.team(r.player.team);
      c.append(h('div', { class: 'mover-row' },
        h('div', {},
          h('div', { class: 'nm' }, r.player.name),
          h('div', { class: 'tm' }, `${team.city} ${team.nickname} · ${r.player.position}`),
        ),
        Sparkline(r.history),
        h('div', { class: ['ch', r.change >= 0 ? 'pos' : 'neg'] }, `${r.change >= 0 ? '+' : ''}${r.change.toFixed(1)}%`),
      ));
    }
    return c;
  };
  wrap.append(col('Climbing', up), col('Cooling', down));
  panel.append(wrap);
  return panel;
}
