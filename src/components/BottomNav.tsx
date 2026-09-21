import { NavLink } from 'react-router-dom';
import { ChartIcon, DumbbellIcon, HistoryIcon, HomeIcon } from './Icons';

const TABS = [
  { to: '/', label: 'Home', Icon: HomeIcon, end: true },
  { to: '/workout', label: 'Workout', Icon: DumbbellIcon, end: false },
  { to: '/history', label: 'History', Icon: HistoryIcon, end: false },
  { to: '/progress', label: 'Progress', Icon: ChartIcon, end: false },
];

export default function BottomNav() {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-line bg-ink/95 backdrop-blur-lg">
      <div className="mx-auto flex w-full max-w-lg items-stretch pb-[var(--safe-bottom)]">
        {TABS.map(({ to, label, Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              `flex flex-1 flex-col items-center justify-center gap-1 py-2.5 text-[0.6875rem] font-bold tracking-wide transition-colors ${
                isActive ? 'text-volt' : 'text-faint'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon size={23} strokeWidth={isActive ? 2.2 : 1.8} />
                <span>{label}</span>
              </>
            )}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
