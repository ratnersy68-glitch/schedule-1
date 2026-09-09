/** Lightweight canvas particle burst for big pulls. No dependencies, no loop when idle. */

const PALETTES = {
  rare: ['#4EA8FF', '#8FD4FF', '#FFFFFF'],
  epic: ['#A970FF', '#D9C2FF', '#FFFFFF'],
  legendary: ['#F5B33C', '#FFE9A8', '#FFFFFF'],
  mythic: ['#FF5470', '#FFB35C', '#5CE1A0', '#4CC9F0', '#FFFFFF'],
  oneofone: ['#FFF0B3', '#F5C24B', '#FFFFFF', '#FFE27A'],
};

export function burst(host, { count = 40, tier = 'legendary', origin = [0.5, 0.45], power = 1 } = {}) {
  if (!count) return () => {};
  const canvas = document.createElement('canvas');
  canvas.className = 'fx-canvas';
  const rect = host.getBoundingClientRect();
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  host.append(canvas);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  const colors = PALETTES[tier] ?? PALETTES.legendary;
  const ox = rect.width * origin[0];
  const oy = rect.height * origin[1];
  const parts = Array.from({ length: count }, () => {
    const angle = Math.random() * Math.PI * 2;
    const speed = (2.2 + Math.random() * 6.5) * power;
    return {
      x: ox, y: oy,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 2.4,
      size: 2 + Math.random() * 5,
      life: 1,
      decay: 0.008 + Math.random() * 0.014,
      spin: (Math.random() - 0.5) * 0.3,
      rot: Math.random() * Math.PI,
      color: colors[Math.floor(Math.random() * colors.length)],
      shape: Math.random() > 0.55 ? 'rect' : 'spark',
    };
  });

  let raf = 0;
  let alive = true;
  const step = () => {
    ctx.clearRect(0, 0, rect.width, rect.height);
    let living = 0;
    for (const p of parts) {
      if (p.life <= 0) continue;
      living += 1;
      p.vy += 0.14;
      p.vx *= 0.988;
      p.x += p.vx;
      p.y += p.vy;
      p.rot += p.spin;
      p.life -= p.decay;
      ctx.save();
      ctx.globalAlpha = Math.max(0, p.life);
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);
      ctx.fillStyle = p.color;
      if (p.shape === 'rect') ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
      else {
        ctx.beginPath();
        ctx.moveTo(0, -p.size); ctx.lineTo(p.size * 0.3, 0);
        ctx.lineTo(0, p.size); ctx.lineTo(-p.size * 0.3, 0);
        ctx.closePath(); ctx.fill();
      }
      ctx.restore();
    }
    if (living && alive) raf = requestAnimationFrame(step);
    else canvas.remove();
  };
  raf = requestAnimationFrame(step);

  return () => { alive = false; cancelAnimationFrame(raf); canvas.remove(); };
}
