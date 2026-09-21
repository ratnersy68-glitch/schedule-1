import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';

interface TimerValue {
  running: boolean;
  duration: number;
  remaining: number;
  finishedAt: number | null;
  start: (seconds: number) => void;
  stop: () => void;
  adjust: (delta: number) => void;
  dismiss: () => void;
}

const TimerContext = createContext<TimerValue | null>(null);

const STORE_KEY = 'forge.timer.v1';

function beep() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    const now = ctx.currentTime;
    [0, 0.22, 0.44].forEach((offset, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = i === 2 ? 1046 : 784;
      gain.gain.setValueAtTime(0.0001, now + offset);
      gain.gain.exponentialRampToValueAtTime(0.22, now + offset + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + offset + 0.18);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now + offset);
      osc.stop(now + offset + 0.2);
    });
    setTimeout(() => ctx.close().catch(() => {}), 1200);
  } catch {
    /* audio is a nicety, never a blocker */
  }
}

export function TimerProvider({ children, soundOn = true }: { children: ReactNode; soundOn?: boolean }) {
  const [endsAt, setEndsAt] = useState<number | null>(null);
  const [duration, setDuration] = useState(90);
  const [remaining, setRemaining] = useState(0);
  const [finishedAt, setFinishedAt] = useState<number | null>(null);
  const soundRef = useRef(soundOn);
  soundRef.current = soundOn;

  // Restore a timer that was running when the app was closed.
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (!raw) return;
      const saved = JSON.parse(raw) as { endsAt: number; duration: number };
      if (saved.endsAt > Date.now()) {
        setEndsAt(saved.endsAt);
        setDuration(saved.duration);
        setRemaining(Math.ceil((saved.endsAt - Date.now()) / 1000));
      } else {
        localStorage.removeItem(STORE_KEY);
      }
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    if (endsAt === null) return;
    const tick = () => {
      const left = (endsAt - Date.now()) / 1000;
      if (left <= 0) {
        setRemaining(0);
        setEndsAt(null);
        setFinishedAt(Date.now());
        localStorage.removeItem(STORE_KEY);
        if (soundRef.current) beep();
        if ('vibrate' in navigator) navigator.vibrate?.([120, 80, 120, 80, 220]);
      } else {
        setRemaining(Math.ceil(left));
      }
    };
    tick();
    const id = window.setInterval(tick, 250);
    return () => window.clearInterval(id);
  }, [endsAt]);

  // Clear the "finished" flash automatically.
  useEffect(() => {
    if (finishedAt === null) return;
    const id = window.setTimeout(() => setFinishedAt(null), 8000);
    return () => window.clearTimeout(id);
  }, [finishedAt]);

  const start = useCallback((seconds: number) => {
    const end = Date.now() + seconds * 1000;
    setDuration(seconds);
    setEndsAt(end);
    setRemaining(seconds);
    setFinishedAt(null);
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify({ endsAt: end, duration: seconds }));
    } catch {
      /* ignore */
    }
  }, []);

  const stop = useCallback(() => {
    setEndsAt(null);
    setRemaining(0);
    setFinishedAt(null);
    localStorage.removeItem(STORE_KEY);
  }, []);

  const adjust = useCallback(
    (delta: number) => {
      setEndsAt((prev) => {
        if (prev === null) return prev;
        const next = Math.max(Date.now() + 1000, prev + delta * 1000);
        setDuration((d) => Math.max(5, d + delta));
        try {
          localStorage.setItem(STORE_KEY, JSON.stringify({ endsAt: next, duration: duration + delta }));
        } catch {
          /* ignore */
        }
        return next;
      });
    },
    [duration]
  );

  const dismiss = useCallback(() => setFinishedAt(null), []);

  const value = useMemo(
    () => ({ running: endsAt !== null, duration, remaining, finishedAt, start, stop, adjust, dismiss }),
    [endsAt, duration, remaining, finishedAt, start, stop, adjust, dismiss]
  );

  return <TimerContext.Provider value={value}>{children}</TimerContext.Provider>;
}

export function useTimer(): TimerValue {
  const ctx = useContext(TimerContext);
  if (!ctx) throw new Error('useTimer must be used inside TimerProvider');
  return ctx;
}
