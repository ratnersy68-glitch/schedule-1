/** Inline price sparkline. Pure SVG, no library, no axis furniture. */
import { h } from '../../core/dom.js';

export function Sparkline(series, { width = 62, height = 22, tone } = {}) {
  const data = series.length > 1 ? series : [series[0] ?? 1, series[0] ?? 1];
  const min = Math.min(...data);
  const max = Math.max(...data);
  const span = max - min || 1;
  const step = width / (data.length - 1);
  const y = (v) => height - 2 - ((v - min) / span) * (height - 4);
  const points = data.map((v, i) => `${(i * step).toFixed(1)},${y(v).toFixed(1)}`);
  const rising = data[data.length - 1] >= data[0];
  const color = tone || (rising ? 'var(--green)' : 'var(--red)');

  const el = h('span', { class: 'mover-spark' });
  el.innerHTML = `<svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" aria-hidden="true" style="width:100%;height:100%">
    <path d="M${points.join('L')}L${width},${height}L0,${height}Z" fill="${color}" fill-opacity=".13"/>
    <path d="M${points.join('L')}" fill="none" stroke="${color}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/>
    <circle cx="${width}" cy="${y(data[data.length - 1]).toFixed(1)}" r="2" fill="${color}"/>
  </svg>`;
  return el;
}
