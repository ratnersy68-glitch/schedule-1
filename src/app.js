/**
 * Application shell: boot sequence, navigation rail, topbar and router.
 * Screens are lazy modules so the first paint only pays for what it shows.
 */
import { h, clear, qs } from './core/dom.js';
import { bus, EVENTS } from './core/events.js';
import { store, S } from './core/store.js';
import { Assets, AssetKeys } from './core/assets.js';
import { money, compactMoney, num } from './core/format.js';

import { Data } from './systems/DataService.js';
import { SaveSystem } from './systems/SaveSystem.js';
import { EconomySystem } from './systems/EconomySystem.js';
import { MarketSystem } from './systems/MarketSystem.js';
import { GradingSystem } from './systems/GradingSystem.js';
import { ProgressionSystem } from './systems/ProgressionSystem.js';
import { ChallengeSystem } from './systems/ChallengeSystem.js';
import { InventorySystem } from './systems/InventorySystem.js';
import { AudioSystem } from './audio/AudioSystem.js';
import { Icon, initToasts, toast, Bar } from './ui/components/ui.js';

const ROUTES = {
  home: { label: 'Clubhouse', icon: 'trophy', bg: 'hall', title: 'Clubhouse', sub: 'Your collection at a glance', load: () => import('./ui/screens/Home.js') },
  store: { label: 'Hobby Shop', icon: 'box', bg: 'hall', title: 'Hobby Shop', sub: 'Sealed hobby boxes only', load: () => import('./ui/screens/Store.js') },
  open: { label: 'Break Room', icon: 'sparkle', bg: 'break', title: 'Break Room', sub: 'Rip your sealed product', load: () => import('./ui/screens/Opening.js'), hidden: false },
  collection: { label: 'Collection', icon: 'cards', bg: 'vault', title: 'Collection', sub: 'Everything you own', load: () => import('./ui/screens/Collection.js') },
  market: { label: 'Marketplace', icon: 'market', bg: 'market', title: 'Marketplace', sub: 'Live comps and consignment', load: () => import('./ui/screens/Market.js') },
  grading: { label: 'Grading', icon: 'shield', bg: 'grading', title: 'Apex Grading Authority', sub: 'Submit, wait, reveal', load: () => import('./ui/screens/Grading.js') },
  stats: { label: 'Ledger', icon: 'chart', bg: 'vault', title: 'Ledger', sub: 'Every dollar in and out', load: () => import('./ui/screens/Stats.js') },
};

const app = {
  route: 'home',
  params: {},
  screen: null,
  els: {},
};

/* ------------------------------------------------------------------ boot */

async function boot() {
  const bootEl = qs('#boot');
  const setNote = (t) => { const n = qs('.boot-note'); if (n) n.textContent = t; };

  setNote('Loading the checklist');
  await Promise.all([Assets.load(''), Data.load('')]);

  setNote('Opening the display case');
  await Assets.preload([
    ...Assets.keysWith('ui.icon-'),
    AssetKeys.bg('hall'),
    AssetKeys.slabShell(), AssetKeys.graderMark(),
  ]);

  const loaded = SaveSystem.load();
  AudioSystem.init(S().settings);
  SaveSystem.start();
  MarketSystem.tick();
  ChallengeSystem.ensureToday();
  initToasts();

  mountShell();
  wireEvents();

  bootEl.classList.add('is-done');
  setTimeout(() => bootEl.remove(), 640);

  const hash = location.hash.slice(1);
  navigate(ROUTES[hash] ? hash : 'home', {}, { replace: true });

  if (loaded.fresh) {
    setTimeout(() => {
      toast({ title: 'Welcome to The Break Room', note: `${money(S().cash)} in the account. Go buy something sealed.`, tone: 'gold', icon: 'gift', ttl: 7000 });
    }, 700);
  } else if (GradingSystem.readyCount()) {
    setTimeout(() => toast({ title: 'Grades are back', note: `${GradingSystem.readyCount()} submission(s) ready to open.`, tone: 'gold', icon: 'shield', ttl: 6000 }), 700);
  }

  setInterval(() => { MarketSystem.tick(); refreshChrome(); }, 20_000);
}

/* ----------------------------------------------------------------- shell */

function mountShell() {
  const root = qs('#app');
  root.className = 'app';
  const bg = h('div', { class: 'app-bg' });

  const rail = h('nav', { class: 'rail' },
    h('div', { class: 'brand' },
      h('div', { class: 'brand-mark' }, 'BR'),
      h('div', { class: 'brand-text' },
        h('div', { class: 'brand-name' }, 'BREAK ROOM'),
        h('div', { class: 'brand-sub' }, 'HOBBY ONLY'),
      ),
    ),
  );

  const navItems = {};
  const group = (label, keys) => {
    rail.append(h('div', { class: 'nav-group-label' }, label));
    for (const key of keys) {
      const r = ROUTES[key];
      const item = h('button', {
        class: 'nav-item', type: 'button',
        onclick: () => navigate(key),
        onpointerenter: () => AudioSystem.play('hover'),
      }, Icon(r.icon), h('span', { class: 'label' }, r.label), h('span', { class: 'badge', hidden: true }));
      navItems[key] = item;
      rail.append(item);
    }
  };
  group('Break', ['home', 'store', 'open']);
  group('Manage', ['collection', 'market', 'grading', 'stats']);

  const levelBox = h('div', { class: 'rail-level' });
  rail.append(h('div', { class: 'rail-foot' }, levelBox));

  const wallet = h('div', { class: 'wallet' },
    h('span', { class: 'coin' }), h('span', { class: 'wallet-value' }, money(S().cash)));
  Assets.mount(wallet.querySelector('.coin'), AssetKeys.icon('currency'));

  const title = h('div', {},
    h('div', { class: 'topbar-title' }, 'Clubhouse'),
    h('div', { class: 'topbar-sub' }, ''),
  );

  const topbar = h('header', { class: 'topbar' },
    title,
    h('div', { class: 'topbar-spacer' }),
    h('div', { class: 'top-metrics' }),
    wallet,
  );

  const page = h('main', { class: 'page' });
  const main = h('div', { class: 'main' }, topbar, page);
  root.append(bg, rail, main);

  app.els = { bg, rail, navItems, wallet, title, page, levelBox, metrics: topbar.querySelector('.top-metrics') };
  refreshChrome();
}

function refreshChrome() {
  const s = S();
  const { wallet, navItems, levelBox, metrics } = app.els;
  if (!wallet) return;

  wallet.querySelector('.wallet-value').textContent = money(s.cash);

  const ready = GradingSystem.readyCount();
  const claims = ChallengeSystem.claimable().length;
  const badges = { grading: ready, home: claims };
  for (const [key, item] of Object.entries(navItems)) {
    item.classList.toggle('is-active', app.route === key);
    const badge = item.querySelector('.badge');
    const n = badges[key] ?? 0;
    badge.hidden = !n;
    badge.textContent = String(n);
    badge.classList.toggle('is-alert', key === 'grading' && n > 0);
  }

  const prog = ProgressionSystem.progress();
  clear(levelBox).append(
    h('div', { class: 'rail-level-head' },
      h('span', { class: 'lvl' }, `LV ${prog.level}`),
      h('span', { class: 'xp' }, `${num(prog.into)}/${num(prog.need)}`)),
    Bar(prog.pct, { tone: 'gold' }),
  );

  const value = EconomySystem.collectionValue((id) => MarketSystem.index(id));
  clear(metrics).append(
    h('div', { class: 'metric' }, h('span', {}, 'Collection'), h('b', {}, compactMoney(value))),
    h('div', { class: 'metric' }, h('span', {}, 'Cards'), h('b', {}, num(InventorySystem.count()))),
  );
}

/* ---------------------------------------------------------------- router */

export async function navigate(route, params = {}, { replace = false } = {}) {
  const def = ROUTES[route];
  if (!def) return;
  const changed = app.route !== route;
  app.route = route;
  app.params = params;
  if (replace) history.replaceState({ route }, '', `#${route}`);
  else if (changed || Object.keys(params).length) history.pushState({ route }, '', `#${route}`);

  const { page, title, bg } = app.els;
  app.els.title.querySelector('.topbar-title').textContent = def.title;
  app.els.title.querySelector('.topbar-sub').textContent = def.sub;

  setBackground(def.bg);
  refreshChrome();

  app.screen?.destroy?.();
  page.scrollTop = 0;
  clear(page);
  const loading = h('div', { class: 'page-loading' }, h('div', { class: 'spinner' }));
  page.append(loading);

  const mod = await def.load();
  loading.remove();
  const view = h('div', { class: 'page-inner page-enter' });
  page.append(view);
  app.screen = mod.default({ mount: view, params, navigate, refresh: refreshChrome });
}

let currentBg = null;
async function setBackground(name) {
  if (currentBg === name) return;
  currentBg = name;
  const { bg } = app.els;
  const holder = h('div', { style: { position: 'absolute', inset: '0' } });
  bg.append(holder);
  await Assets.mount(holder, AssetKeys.bg(name), { preserveAspectRatio: 'xMidYMid slice' });
  const svg = holder.querySelector('svg') || holder.querySelector('img');
  if (svg) {
    requestAnimationFrame(() => svg.classList.add('is-on'));
    for (const old of [...bg.children]) {
      if (old !== holder) { old.querySelector('svg,img')?.classList.remove('is-on'); setTimeout(() => old.remove(), 700); }
    }
  }
}

/* ---------------------------------------------------------------- events */

function wireEvents() {
  window.addEventListener('popstate', () => {
    const hash = location.hash.slice(1) || 'home';
    if (ROUTES[hash]) navigate(hash, {}, { replace: true });
  });

  bus.on(EVENTS.CASH_CHANGED, () => {
    refreshChrome();
    const { wallet } = app.els;
    wallet.classList.remove('is-bump');
    void wallet.offsetWidth;
    wallet.classList.add('is-bump');
  });

  bus.on(EVENTS.STATE_CHANGED, () => refreshChrome());

  bus.on(EVENTS.LEVEL_UP, ({ level, reward, unlocked }) => {
    AudioSystem.play('levelUp');
    toast({
      title: `Level ${level}`,
      note: unlocked.length ? `${money(reward)} bonus. Unlocked ${unlocked[0].name}.` : `${money(reward)} bonus credited.`,
      tone: 'gold', icon: 'level', ttl: 6500,
    });
  });

  bus.on(EVENTS.CHALLENGE_DONE, (row) => {
    AudioSystem.play('challenge');
    toast({ title: 'Challenge complete', note: `${row.label} · ${money(row.reward)}`, tone: 'good', icon: 'check' });
  });

  bus.on(EVENTS.NAVIGATE, ({ route, params }) => navigate(route, params));

  document.addEventListener('keydown', (e) => {
    if (e.target.matches('input, textarea, select')) return;
    const map = { 1: 'home', 2: 'store', 3: 'open', 4: 'collection', 5: 'market', 6: 'grading', 7: 'stats' };
    if (map[e.key]) navigate(map[e.key]);
  });
}

boot().catch((err) => {
  console.error(err);
  const b = qs('#boot');
  if (b) b.innerHTML = `<div class="boot-name">Something went wrong</div><div class="boot-note">${err.message}</div>`;
});
