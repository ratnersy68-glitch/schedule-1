import { useEffect, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft } from './Icons';

export function Screen({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`page mx-auto w-full max-w-lg px-4 ${className}`}>{children}</div>;
}

export function TopBar({
  title,
  subtitle,
  right,
  back,
  onBack,
}: {
  title: string;
  subtitle?: string;
  right?: ReactNode;
  back?: boolean;
  onBack?: () => void;
}) {
  const navigate = useNavigate();
  return (
    <header className="pt-safe sticky top-0 z-30 -mx-4 mb-4 border-b border-line/70 bg-ink/90 px-4 pb-3 backdrop-blur-lg">
      <div className="flex items-center gap-3">
        {back && (
          <button
            type="button"
            aria-label="Go back"
            onClick={() => (onBack ? onBack() : navigate(-1))}
            className="-ml-2 flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-muted active:bg-surface-2"
          >
            <ChevronLeft />
          </button>
        )}
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-[1.35rem] leading-tight font-extrabold tracking-tight">{title}</h1>
          {subtitle && <p className="truncate text-[0.8125rem] text-muted">{subtitle}</p>}
        </div>
        {right}
      </div>
    </header>
  );
}

export function Card({
  children,
  className = '',
  as = 'div',
  ...rest
}: {
  children: ReactNode;
  className?: string;
  as?: 'div' | 'button' | 'li';
} & React.HTMLAttributes<HTMLElement>) {
  const Tag = as as 'div';
  return (
    <Tag className={`card p-4 ${className}`} {...rest}>
      {children}
    </Tag>
  );
}

export function Stat({
  label,
  value,
  suffix,
  accent,
  icon,
}: {
  label: string;
  value: string | number;
  suffix?: string;
  accent?: boolean;
  icon?: ReactNode;
}) {
  return (
    <div className="card px-3.5 py-3">
      <div className="flex items-center gap-1.5">
        {icon && <span className={accent ? 'text-volt' : 'text-faint'}>{icon}</span>}
        <span className="label-caps">{label}</span>
      </div>
      <div className="mt-1.5 flex items-baseline gap-1">
        <span
          className={`stat-value text-[1.75rem] leading-none font-extrabold ${accent ? 'text-volt' : 'text-chalk'}`}
        >
          {value}
        </span>
        {suffix && <span className="text-xs font-semibold text-faint">{suffix}</span>}
      </div>
    </div>
  );
}

export function SectionTitle({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mt-6 mb-2.5 flex items-center justify-between">
      <h2 className="label-caps">{children}</h2>
      {action}
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon?: ReactNode;
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <div className="card flex flex-col items-center px-6 py-10 text-center">
      {icon && <div className="mb-3 text-faint">{icon}</div>}
      <p className="font-bold">{title}</p>
      {body && <p className="mt-1.5 max-w-xs text-sm text-muted">{body}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function Pill({
  children,
  active,
  onClick,
  className = '',
}: {
  children: ReactNode;
  active?: boolean;
  onClick?: () => void;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`shrink-0 rounded-full px-3.5 py-2 text-[0.8125rem] font-bold whitespace-nowrap transition-colors ${
        active ? 'bg-volt text-ink' : 'bg-surface-2 text-muted'
      } ${className}`}
    >
      {children}
    </button>
  );
}

export function Sheet({
  open,
  onClose,
  title,
  children,
  full,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  full?: boolean;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-end" role="dialog" aria-modal="true" aria-label={title}>
      <button type="button" aria-label="Close" className="absolute inset-0 bg-black/70" onClick={onClose} />
      <div
        className={`animate-pop relative mx-auto flex w-full max-w-lg flex-col overflow-hidden rounded-t-3xl border-t border-line bg-surface ${
          full ? 'h-[92vh]' : 'max-h-[88vh]'
        }`}
      >
        <div className="flex items-center justify-between border-b border-line px-4 py-3.5">
          <h2 className="text-lg font-extrabold tracking-tight">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full bg-surface-2 px-3.5 py-1.5 text-sm font-bold text-muted"
          >
            Done
          </button>
        </div>
        <div className="flex-1 overflow-y-auto overscroll-contain px-4 pt-4 pb-[calc(var(--safe-bottom)+1.5rem)]">
          {children}
        </div>
      </div>
    </div>
  );
}

export function Banner({ children, tone = 'volt' }: { children: ReactNode; tone?: 'volt' | 'danger' }) {
  const styles =
    tone === 'danger'
      ? 'border-danger/40 bg-danger/10 text-danger'
      : 'border-volt/30 bg-volt/10 text-volt';
  return <div className={`rounded-xl border px-3.5 py-2.5 text-sm font-semibold ${styles}`}>{children}</div>;
}
