/** Hyperscript-lite. Keeps view code declarative without a framework dependency. */

export function h(tag, props = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (v === null || v === undefined || v === false) continue;
    if (k === 'class') el.className = Array.isArray(v) ? v.filter(Boolean).join(' ') : v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'html') el.innerHTML = v;
    else if (k === 'ref' && typeof v === 'function') v(el);
    else if (k in el && k !== 'list' && typeof v !== 'object') el[k] = v;
    else el.setAttribute(k, v);
  }
  append(el, children);
  return el;
}

export function append(parent, children) {
  for (const c of children.flat(4)) {
    if (c === null || c === undefined || c === false) continue;
    parent.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return parent;
}

export const frag = (...children) => append(document.createDocumentFragment(), children);
export const clear = (el) => { while (el.firstChild) el.firstChild.remove(); return el; };
export const qs = (sel, root = document) => root.querySelector(sel);
export const qsa = (sel, root = document) => [...root.querySelectorAll(sel)];

/** Next animation frame as a promise. */
export const raf = () => new Promise(requestAnimationFrame);
export const wait = (ms) => new Promise((r) => setTimeout(r, ms));

/** Resolves when the element's transitions/animations settle (or after a cap). */
export function transitionEnd(el, cap = 1200) {
  return new Promise((resolve) => {
    let done = false;
    const finish = () => { if (!done) { done = true; el.removeEventListener('transitionend', finish); resolve(); } };
    el.addEventListener('transitionend', finish, { once: true });
    setTimeout(finish, cap);
  });
}

export function onClickOutside(el, fn) {
  const handler = (e) => { if (!el.contains(e.target)) fn(e); };
  setTimeout(() => document.addEventListener('pointerdown', handler), 0);
  return () => document.removeEventListener('pointerdown', handler);
}
