import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, EmptyState, Screen, SectionTitle, TopBar } from '../components/ui';
import DragList from '../components/DragList';
import { CalendarIcon, ChevronRight, DumbbellIcon, GripIcon, PlusIcon } from '../components/Icons';
import { DAY_SHORT } from '../lib/format';
import { uid } from '../lib/id';

export default function Builder() {
  const navigate = useNavigate();
  const { state, dispatch } = useStore();
  const split = state.split;
  const [name, setName] = useState(split?.name ?? '');

  if (!split) {
    return (
      <Screen>
        <TopBar title="Your split" back />
        <EmptyState
          title="No split yet"
          body="Create a training split to get started."
          action={
            <Link to="/setup" className="btn btn-primary h-12 px-6">
              Create split
            </Link>
          }
        />
      </Screen>
    );
  }

  const addDay = () => {
    const day = {
      id: uid('day-'),
      name: `Day ${split.days.length + 1}`,
      dayOfWeek: null,
      exercises: [],
    };
    dispatch({ type: 'addDay', day });
    navigate(`/builder/day/${day.id}`);
  };

  return (
    <Screen>
      <TopBar title="Your split" subtitle={`${split.days.length} workout days`} back />

      <Card>
        <label className="label-caps" htmlFor="split-name">
          Split name
        </label>
        <input
          id="split-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onBlur={() => dispatch({ type: 'renameSplit', name: name.trim() || 'My Split' })}
          className="field mt-2 font-bold"
        />
      </Card>

      <SectionTitle
        action={
          <button type="button" onClick={addDay} className="flex items-center gap-1 text-xs font-bold text-volt">
            <PlusIcon size={15} strokeWidth={2.4} /> Add day
          </button>
        }
      >
        Workout days · drag to reorder
      </SectionTitle>

      {split.days.length === 0 ? (
        <EmptyState
          icon={<DumbbellIcon size={28} />}
          title="No workout days"
          body="Add your first day and fill it with exercises."
          action={
            <button type="button" onClick={addDay} className="btn btn-primary h-12 px-6">
              Add workout day
            </button>
          }
        />
      ) : (
        <DragList
          items={split.days}
          keyOf={(d) => d.id}
          onReorder={(from, to) => dispatch({ type: 'reorderDays', from, to })}
          renderItem={(day, _i, handle, dragging) => (
            <div
              className={`card flex items-stretch overflow-hidden ${dragging ? 'border-volt/60' : ''}`}
              style={{ padding: 0 }}
            >
              <button
                type="button"
                aria-label={`Reorder ${day.name}`}
                className="flex w-11 shrink-0 items-center justify-center text-faint active:text-chalk"
                {...handle}
              >
                <GripIcon size={20} />
              </button>
              <Link to={`/builder/day/${day.id}`} className="flex min-w-0 flex-1 items-center gap-3 py-3.5 pr-3.5">
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-bold">{day.name}</span>
                  <span className="mt-0.5 flex items-center gap-2 text-xs text-muted">
                    <span className="flex items-center gap-1">
                      <CalendarIcon size={13} />
                      {day.dayOfWeek === null ? 'Unscheduled' : DAY_SHORT[day.dayOfWeek]}
                    </span>
                    <span className="text-faint">·</span>
                    <span>{day.exercises.length} exercises</span>
                  </span>
                </span>
                <span className="text-faint">
                  <ChevronRight size={18} />
                </span>
              </Link>
            </div>
          )}
        />
      )}

      <button type="button" onClick={addDay} className="btn btn-secondary mt-3 h-12 w-full">
        <PlusIcon size={18} /> Add workout day
      </button>

      <SectionTitle>Start fresh</SectionTitle>
      <Link to="/setup" className="btn btn-ghost h-12 w-full">
        Rebuild split from a template
      </Link>
      <p className="mt-2 text-center text-xs text-faint">Your workout history is never deleted by this.</p>
    </Screen>
  );
}
