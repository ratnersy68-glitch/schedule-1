import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { SeriesPoint } from '../lib/stats';
import { fmtDate } from '../lib/format';

interface Props {
  points: SeriesPoint[];
  formatValue: (value: number) => string;
  height?: number;
  accent?: string;
}

const PAD_X = 12;
const PAD_Y = 16;

/** Compact progression chart. No chart library — just a measured SVG path. */
export default function Chart({ points, formatValue, height = 176, accent = '#D8FF36' }: Props) {
  const [selected, setSelected] = useState<number | null>(null);
  const [width, setWidth] = useState(320);
  const wrapRef = useRef<HTMLDivElement>(null);
  const svgRef = useRef<SVGSVGElement>(null);

  // Measure so points stay circular and strokes stay crisp at any screen width.
  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => setWidth(Math.max(200, el.clientWidth));
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    setSelected(null);
  }, [points]);

  const geo = useMemo(() => {
    if (points.length === 0) return null;
    const values = points.map((p) => p.value);
    const rawMin = Math.min(...values);
    const rawMax = Math.max(...values);
    const span = rawMax - rawMin || Math.max(1, rawMax * 0.1);
    const min = rawMin - span * 0.15;
    const max = rawMax + span * 0.15;

    const x = (i: number) =>
      points.length === 1 ? width / 2 : PAD_X + (i * (width - PAD_X * 2)) / (points.length - 1);
    const y = (v: number) => height - PAD_Y - ((v - min) / (max - min)) * (height - PAD_Y * 2);

    const coords = points.map((p, i) => ({ x: x(i), y: y(p.value), ...p }));
    const line = coords.map((c, i) => `${i === 0 ? 'M' : 'L'}${c.x.toFixed(1)},${c.y.toFixed(1)}`).join(' ');
    const area = `${line} L${coords[coords.length - 1].x.toFixed(1)},${height - PAD_Y} L${coords[0].x.toFixed(1)},${height - PAD_Y} Z`;
    return { coords, line, area, rawMin, rawMax };
  }, [points, width, height]);

  const pick = (clientX: number) => {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect || !geo) return;
    const px = clientX - rect.left;
    let best = 0;
    let bestDist = Infinity;
    geo.coords.forEach((c, i) => {
      const d = Math.abs(c.x - px);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    });
    setSelected(best);
  };

  if (!geo) {
    return (
      <div ref={wrapRef} className="flex h-36 items-center justify-center rounded-xl border border-dashed border-line text-sm text-faint">
        Not enough data yet
      </div>
    );
  }

  const activeIndex = selected ?? geo.coords.length - 1;
  const active = geo.coords[activeIndex];
  const first = points[0];
  const last = points[points.length - 1];
  const delta = last.value - first.value;

  return (
    <div ref={wrapRef}>
      <div className="mb-2 flex items-end justify-between gap-3">
        <div className="min-w-0">
          <div className="stat-value truncate text-2xl font-extrabold">{formatValue(active.value)}</div>
          <div className="text-xs text-muted">{fmtDate(active.date)}</div>
        </div>
        {points.length > 1 && (
          <div className="shrink-0 text-right">
            <div
              className={`stat-value text-sm font-bold ${delta > 0 ? 'text-volt' : delta < 0 ? 'text-danger' : 'text-muted'}`}
            >
              {delta > 0 ? '+' : ''}
              {formatValue(delta)}
            </div>
            <div className="label-caps">all time</div>
          </div>
        )}
      </div>

      <svg
        ref={svgRef}
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        className="touch-none select-none"
        onPointerDown={(e) => pick(e.clientX)}
        onPointerMove={(e) => e.buttons > 0 && pick(e.clientX)}
        role="img"
        aria-label={`Progression chart, ${points.length} sessions, latest ${formatValue(last.value)}`}
      >
        <defs>
          <linearGradient id="forge-area" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={accent} stopOpacity="0.26" />
            <stop offset="100%" stopColor={accent} stopOpacity="0" />
          </linearGradient>
        </defs>

        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={0}
            x2={width}
            y1={PAD_Y + f * (height - PAD_Y * 2)}
            y2={PAD_Y + f * (height - PAD_Y * 2)}
            stroke="#2c2c32"
            strokeWidth="1"
          />
        ))}

        {points.length > 1 && <path d={geo.area} fill="url(#forge-area)" />}
        {points.length > 1 && (
          <path
            d={geo.line}
            fill="none"
            stroke={accent}
            strokeWidth="2.5"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        )}

        {geo.coords.map((c, i) => (
          <circle
            key={`${c.date}-${i}`}
            cx={c.x}
            cy={c.y}
            r={i === activeIndex ? 5.5 : 3}
            fill={i === activeIndex ? accent : '#09090a'}
            stroke={accent}
            strokeWidth="2"
          />
        ))}
      </svg>

      <div className="mt-1 flex justify-between gap-2 text-[0.6875rem] text-faint">
        <span>{fmtDate(first.date)}</span>
        <span className="tnum truncate">
          {formatValue(geo.rawMin)} – {formatValue(geo.rawMax)}
        </span>
        <span>{fmtDate(last.date)}</span>
      </div>
    </div>
  );
}
