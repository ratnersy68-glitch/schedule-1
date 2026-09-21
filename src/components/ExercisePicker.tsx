import { useMemo, useState } from 'react';
import { useStore } from '../state/store';
import { GROUP_ACCENT, GROUP_ORDER } from '../lib/exercises';
import type { MuscleGroup } from '../lib/types';
import { uid } from '../lib/id';
import { Pill, Sheet } from './ui';
import { PlusIcon, SearchIcon } from './Icons';

interface Props {
  open: boolean;
  onClose: () => void;
  onPick: (exerciseId: string) => void;
  title?: string;
}

export default function ExercisePicker({ open, onClose, onPick, title = 'Add Exercise' }: Props) {
  const { allExercises, dispatch } = useStore();
  const [query, setQuery] = useState('');
  const [group, setGroup] = useState<MuscleGroup | 'All'>('All');
  const [newGroup, setNewGroup] = useState<MuscleGroup>('Chest');

  const trimmed = query.trim();
  const filtered = useMemo(() => {
    const q = trimmed.toLowerCase();
    return allExercises.filter(
      (ex) => (group === 'All' || ex.group === group) && (!q || ex.name.toLowerCase().includes(q))
    );
  }, [allExercises, group, trimmed]);

  const exactExists = allExercises.some((ex) => ex.name.toLowerCase() === trimmed.toLowerCase());

  const grouped = useMemo(() => {
    const map = new Map<MuscleGroup, typeof filtered>();
    for (const ex of filtered) {
      const list = map.get(ex.group) ?? [];
      list.push(ex);
      map.set(ex.group, list);
    }
    return GROUP_ORDER.filter((g) => map.has(g)).map((g) => [g, map.get(g)!] as const);
  }, [filtered]);

  const reset = () => {
    setQuery('');
    setGroup('All');
  };

  const pick = (id: string) => {
    onPick(id);
    reset();
    onClose();
  };

  const createCustom = () => {
    const name = trimmed;
    if (!name) return;
    const exercise = { id: uid('cx-'), name, group: newGroup, custom: true };
    dispatch({ type: 'addCustomExercise', exercise });
    pick(exercise.id);
  };

  return (
    <Sheet
      open={open}
      onClose={() => {
        reset();
        onClose();
      }}
      title={title}
      full
    >
      <div className="sticky -top-4 z-10 -mx-4 -mt-4 mb-3 bg-surface px-4 pt-4 pb-3">
        <div className="relative">
          <span className="absolute top-1/2 left-3 -translate-y-1/2 text-faint">
            <SearchIcon size={18} />
          </span>
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search or type a new exercise"
            className="field pl-10"
          />
        </div>
        <div className="hide-scroll mt-3 flex gap-2 overflow-x-auto">
          <Pill active={group === 'All'} onClick={() => setGroup('All')}>
            All
          </Pill>
          {GROUP_ORDER.map((g) => (
            <Pill key={g} active={group === g} onClick={() => setGroup(g)}>
              {g}
            </Pill>
          ))}
        </div>
      </div>

      {trimmed && !exactExists && (
        <div className="card mb-4 p-3.5">
          <div className="flex items-center gap-2 text-sm font-bold">
            <PlusIcon size={18} className="text-volt" />
            Create “{trimmed}”
          </div>
          <div className="hide-scroll mt-3 flex gap-2 overflow-x-auto">
            {GROUP_ORDER.map((g) => (
              <Pill key={g} active={newGroup === g} onClick={() => setNewGroup(g)}>
                {g}
              </Pill>
            ))}
          </div>
          <button type="button" onClick={createCustom} className="btn btn-primary mt-3 h-11 w-full">
            Add custom exercise
          </button>
        </div>
      )}

      {grouped.length === 0 && !trimmed && <p className="py-6 text-center text-sm text-muted">No exercises found.</p>}

      <div className="flex flex-col gap-5">
        {grouped.map(([g, list]) => (
          <section key={g}>
            <div className="mb-2 flex items-center gap-2">
              <span className="h-2 w-2 rounded-full" style={{ background: GROUP_ACCENT[g] }} />
              <span className="label-caps">{g}</span>
            </div>
            <div className="flex flex-col gap-1.5">
              {list.map((ex) => (
                <button
                  key={ex.id}
                  type="button"
                  onClick={() => pick(ex.id)}
                  className="flex items-center justify-between rounded-xl border border-line bg-surface-2 px-3.5 py-3 text-left active:bg-surface-3"
                >
                  <span className="font-semibold">{ex.name}</span>
                  {ex.custom && <span className="label-caps">custom</span>}
                </button>
              ))}
            </div>
          </section>
        ))}
      </div>
    </Sheet>
  );
}
