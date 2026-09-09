/** Small shared building blocks: icons, buttons, chips, stats, bars, modal, toast. */
import { h, clear, append } from '../../core/dom.js';
import { Assets, AssetKeys } from '../../core/assets.js';
import { AudioSystem } from '../../audio/AudioSystem.js';
import { bus, EVENTS } from '../../core/events.js';

/* --- icon ------------------------------------------------------------------ */
export function Icon(name, { className = '' } = {}) {
  const el = h('span', { class: `ico ${className}` });
  const markup = Assets.markupSync(AssetKeys.icon(name));
  if (markup) el.innerHTML = markup;
  else Assets.mount(el, AssetKeys.icon(name));
  return el;
}

/* --- button ---------------------------------------------------------------- */
export function Button(label, { variant = '', size = '', icon, onClick, disabled = false, block = false, title, sound = 'click' } = {}) {
  const btn = h('button', {
    class: ['btn', variant && `btn-${variant}`, size && `btn-${size}`, block && 'btn-block'],
    disabled, title, type: 'button',
    onclick: (e) => { if (btn.disabled) return; AudioSystem.play(sound); onClick?.(e); },
    onpointerenter: () => { if (!btn.disabled) AudioSystem.play('hover'); },
  });
  if (icon) btn.append(Icon(icon));
  if (label) btn.append(h('span', {}, label));
  btn.setLoading = (on) => { btn.classList.toggle('is-loading', on); btn.disabled = on; };
  return btn;
}

/* --- chip ------------------------------------------------------------------ */
export function Chip(label, { on = false, count, onClick, color, dot = false } = {}) {
  const el = h(onClick ? 'button' : 'span', {
    class: ['chip', on && 'is-on', color && 'tag-rarity'],
    style: color ? { '--rc': color } : undefined,
    type: onClick ? 'button' : undefined,
    onclick: onClick ? () => { AudioSystem.play('click'); onClick(); } : undefined,
  });
  if (dot && color) el.append(h('i', { class: 'dot', style: { background: color } }));
  el.append(h('span', {}, label));
  if (count !== undefined) el.append(h('span', { class: 'chip-count' }, String(count)));
  return el;
}

/* --- stat ------------------------------------------------------------------ */
export function Stat(label, value, { note, accent = 'var(--blue)', gold = false } = {}) {
  return h('div', { class: 'stat', style: { '--accent': accent } },
    h('div', { class: 'stat-label' }, label),
    h('div', { class: ['stat-value', gold && 'is-gold'] }, value),
    note ? h('div', { class: 'stat-note' }, note) : null,
  );
}

/* --- progress -------------------------------------------------------------- */
export function Bar(pct, { tone = '' } = {}) {
  return h('div', { class: ['bar', tone && `is-${tone}`] }, h('i', { style: { width: `${Math.max(0, Math.min(1, pct)) * 100}%` } }));
}

/* --- modal ----------------------------------------------------------------- */
export function Modal({ title, body, actions = [], width = 640, onClose, dismissable = true }) {
  const scrim = h('div', { class: 'scrim' });
  const modal = h('div', { class: 'modal', style: { '--modal-w': `${width}px` }, role: 'dialog', 'aria-modal': 'true' });

  const close = () => {
    scrim.style.animation = 'fadeIn var(--d-base) reverse both';
    setTimeout(() => scrim.remove(), 160);
    onClose?.();
  };

  append(modal, [
    h('div', { class: 'modal-head' },
      h('div', { class: 'modal-title' }, title),
      h('div', { class: 'spacer' }),
      dismissable ? h('button', { class: 'icon-btn', onclick: close, 'aria-label': 'Close' }, Icon('close')) : null,
    ),
    h('div', { class: 'modal-body' }, body),
    actions.length ? h('div', { class: 'modal-foot' }, ...actions) : null,
  ]);

  scrim.append(modal);
  if (dismissable) {
    scrim.addEventListener('pointerdown', (e) => { if (e.target === scrim) close(); });
    const key = (e) => { if (e.key === 'Escape') { close(); document.removeEventListener('keydown', key); } };
    document.addEventListener('keydown', key);
  }
  document.body.append(scrim);
  return { el: scrim, close, body: modal.querySelector('.modal-body') };
}

/* --- toast ----------------------------------------------------------------- */
let toastHost = null;
export function initToasts() {
  toastHost = h('div', { class: 'toasts' });
  document.body.append(toastHost);
  bus.on(EVENTS.TOAST, (t) => toast(t));
}

export function toast({ title, note, tone = 'info', icon = 'info', ttl = 4200 }) {
  if (!toastHost) return;
  const el = h('div', { class: `toast t-${tone}` },
    Icon(icon),
    h('div', {},
      h('div', { class: 'toast-title' }, title),
      note ? h('div', { class: 'toast-note' }, note) : null,
    ),
  );
  toastHost.append(el);
  setTimeout(() => {
    el.classList.add('is-out');
    setTimeout(() => el.remove(), 260);
  }, ttl);
  return el;
}

/* --- empty state ------------------------------------------------------------ */
export function Empty(title, note, icon = 'cards') {
  return h('div', { class: 'empty' }, Icon(icon), h('div', { class: 'empty-title' }, title), note ? h('div', {}, note) : null);
}

/* --- key/value list --------------------------------------------------------- */
export function KV(rows) {
  const dl = h('dl', { class: 'kv-list' });
  for (const [k, v, cls] of rows) {
    if (v === null || v === undefined) continue;
    dl.append(h('div', { class: 'kv' }, h('dt', {}, k), h('dd', { class: cls || '' }, v)));
  }
  return dl;
}
