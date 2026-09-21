interface IconProps {
  size?: number;
  className?: string;
  strokeWidth?: number;
}

function base({ size = 22, className = '', strokeWidth = 1.9 }: IconProps) {
  return {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    className,
    'aria-hidden': true,
  };
}

export const HomeIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M3 10.2 12 3.5l9 6.7V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" />
  </svg>
);

export const DumbbellIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M6.5 8v8M3.5 10v4M17.5 8v8M20.5 10v4M6.5 12h11" />
  </svg>
);

export const HistoryIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M12 7v5l3.2 2M3.5 12a8.5 8.5 0 1 0 2.2-5.7M3.5 4v3.2h3.2" />
  </svg>
);

export const ChartIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M4 19V5M4 19h16M8 16V11M12.5 16V7.5M17 16v-4" />
  </svg>
);

export const PlusIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M12 5v14M5 12h14" />
  </svg>
);

export const CheckIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="m4.5 12.5 5 5 10-11" />
  </svg>
);

export const ChevronRight = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="m9 5 7 7-7 7" />
  </svg>
);

export const ChevronLeft = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="m15 5-7 7 7 7" />
  </svg>
);

export const ChevronDown = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="m5 9 7 7 7-7" />
  </svg>
);

export const CloseIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M6 6l12 12M18 6 6 18" />
  </svg>
);

export const TrashIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M4 7h16M10 4h4M9 7v12m6-12v12M6 7l.8 13a1 1 0 0 0 1 .9h8.4a1 1 0 0 0 1-.9L18 7" />
  </svg>
);

export const GripIcon = (p: IconProps) => (
  <svg {...base({ ...p, strokeWidth: 2.4 })}>
    <path d="M9 7h.01M15 7h.01M9 12h.01M15 12h.01M9 17h.01M15 17h.01" />
  </svg>
);

export const SettingsIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <circle cx="12" cy="12" r="3.2" />
    <path d="M19.4 14a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a2 2 0 1 1-4 0v-.1A1.7 1.7 0 0 0 7 18.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 3 14H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.2 7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.7 1.7 0 0 0 10 3.3V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 2.9 1.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0 1.2 2.9H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
  </svg>
);

export const FlameIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M12 3s5.5 4.2 5.5 9.2A5.5 5.5 0 0 1 12 18a5.5 5.5 0 0 1-5.5-5.8C6.5 9 9 7.2 9 7.2s.4 2.3 1.8 2.8C11.4 8.3 12 5.7 12 3Z" />
  </svg>
);

export const TrophyIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M7 4h10v5a5 5 0 0 1-10 0zM7 6H4.5v1.5A3.5 3.5 0 0 0 7.6 11M17 6h2.5v1.5A3.5 3.5 0 0 1 16.4 11M9.5 20h5M12 14v6" />
  </svg>
);

export const TimerIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <circle cx="12" cy="13.5" r="7.5" />
    <path d="M12 10v3.7l2.4 1.6M9.5 2.5h5" />
  </svg>
);

export const EditIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17v3z" />
  </svg>
);

export const PlayIcon = (p: IconProps) => (
  <svg {...base({ ...p, strokeWidth: 1.6 })}>
    <path d="M7 4.8 19 12 7 19.2z" fill="currentColor" />
  </svg>
);

export const CalendarIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <rect x="3.5" y="5" width="17" height="15.5" rx="2.5" />
    <path d="M3.5 10h17M8 3.5V6.5M16 3.5V6.5" />
  </svg>
);

export const DownloadIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M12 4v11m0 0 4-4m-4 4-4-4M4 19h16" />
  </svg>
);

export const UploadIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <path d="M12 16V5m0 0 4 4m-4-4L8 9M4 19h16" />
  </svg>
);

export const SearchIcon = (p: IconProps) => (
  <svg {...base(p)}>
    <circle cx="11" cy="11" r="6.5" />
    <path d="m16 16 4.5 4.5" />
  </svg>
);
