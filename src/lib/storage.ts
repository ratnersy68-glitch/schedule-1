import type { AppState } from './types';

export const STORAGE_KEY = 'forge.training.log.v1';
export const SCHEMA_VERSION = 1;

export const initialState: AppState = {
  version: SCHEMA_VERSION,
  onboarded: false,
  split: null,
  customExercises: [],
  activeSession: null,
  history: [],
  settings: {
    unit: 'lb',
    defaultRest: 90,
    restPresets: [30, 60, 90, 120, 180],
    soundOn: true,
  },
};

/** Defensive merge so older or partial payloads still load. */
export function normalize(raw: unknown): AppState {
  if (!raw || typeof raw !== 'object') return { ...initialState };
  const data = raw as Partial<AppState>;
  const history = Array.isArray(data.history) ? data.history.filter((s) => s && Array.isArray(s.exercises)) : [];
  return {
    version: SCHEMA_VERSION,
    onboarded: Boolean(data.onboarded),
    split: data.split && Array.isArray(data.split.days) ? data.split : null,
    customExercises: Array.isArray(data.customExercises) ? data.customExercises : [],
    activeSession:
      data.activeSession && Array.isArray(data.activeSession.exercises) ? data.activeSession : null,
    history: history.sort((a, b) => (b.finishedAt ?? b.startedAt) - (a.finishedAt ?? a.startedAt)),
    settings: {
      ...initialState.settings,
      ...(data.settings ?? {}),
      restPresets:
        Array.isArray(data.settings?.restPresets) && data.settings.restPresets.length
          ? data.settings.restPresets
          : initialState.settings.restPresets,
    },
  };
}

export function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...initialState };
    return normalize(JSON.parse(raw));
  } catch {
    return { ...initialState };
  }
}

export function saveState(state: AppState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    /* quota or private mode — the app keeps working in memory */
  }
}

export function exportPayload(state: AppState) {
  return {
    app: 'forge-training-log',
    version: SCHEMA_VERSION,
    exportedAt: new Date().toISOString(),
    data: state,
  };
}

export function parseImport(text: string): AppState {
  const parsed = JSON.parse(text) as { data?: unknown } | unknown;
  const payload =
    parsed && typeof parsed === 'object' && 'data' in (parsed as Record<string, unknown>)
      ? (parsed as { data: unknown }).data
      : parsed;
  const state = normalize(payload);
  if (!state.split && state.history.length === 0) {
    throw new Error('No Forge data found in that file.');
  }
  return state;
}
