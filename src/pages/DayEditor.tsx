import { useState } from 'react';
import { Navigate, useNavigate, useParams } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, EmptyState, Screen, SectionTitle, Sheet, TopBar } from '../components/ui';
import DragList from '../components/DragList';
import ExercisePicker from '../components/ExercisePicker';
import NumberStepper from '../components/NumberStepper';
import { DumbbellIcon, GripIcon, PlayIcon, PlusIcon, TrashIcon } from '../components/Icons';
import { DAY_LETTER, DAY_NAMES, DAY_SHORT } from '../lib/format';
import { uid } from '../lib/id';
import type { PlanExercise } from '../lib/types';

export default function DayEditor() {
  const { dayId = '' } = useParams();
  const navigate = useNavigate();
  const { state, dispatch, exerciseName, buildSession } = useStore();
  const day = state.split?.days.find((d) => d.id === dayId) ?? null;

  const [name, setName] = useState(day?.name ?? '');
  const [picking, setPicking] = useState(false);
  const [editing, setEditing] = useState<PlanExercise | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);

  if (!day) return <Navigate to="/builder" replace />;

  const addExercise = (exerciseId: string) => {
    dispatch({
      type: 'addPlanExercise',
      dayId: day.id,
      exercise: { id: uid('pe-'), exerciseId, targetSets: 3, repMin: 8, repMax: 12 },
    });
  };

  const patchExercise = (planId: string, patch: Partial<Omit<PlanExercise, 'id'>>) => {
    dispatch({ type: 'updatePlanExercise', dayId: day.id, planId, patch });
    setEditing((prev) => (prev && prev.id === planId ? { ...prev, ...patch } : prev));
  };

  const startThisWorkout = () => {
    if (state.activeSession) {
      navigate('/workout');
      return;
    }
    dispatch({ type: 'startSession', session: buildSession(day) });
    navigate('/workout');
  };

  return (
    <Screen>
      <TopBar
        title={day.name || 'Workout day'}
        subtitle={day.dayOfWeek === null ? 'Unscheduled' : DAY_SHORT[day.dayOfWeek]}
        back
        onBack={() => navigate('/builder')}
        right={
          <button
            type="button"
            aria-label="Delete day"
            onClick={() => setConfirmDelete(true)}
            className="flex h-10 w-10 items-center justify-center rounded-full text-faint active:bg-surface-2"
          >
            <TrashIcon size={19} />
          </button>
        }
      />

      <Card>
        <label className="label-caps" htmlFor="day-name">
          Workout name
        </label>
        <input
          id="day-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onBlur={() => dispatch({ type: 'updateDay', dayId: day.id, patch: { name: name.trim() || 'Workout' } })}
          placeholder="Chest + Triceps"
          className="field mt-2 font-bold"
        />
        <div className="label-caps mt-4 mb-2">Day of week</div>
        <div className="flex gap-1.5">
          {DAY_LETTER.map((letter, dow) => (
            <button
              key={dow}
              type="button"
              aria-label={DAY_NAMES[dow]}
              onClick={() =>
                dispatch({
                  type: 'updateDay',
                  dayId: day.id,
                  patch: { dayOfWeek: day.dayOfWeek === dow ? null : dow },
                })
              }
              className={`h-11 flex-1 rounded-lg text-sm font-bold transition-colors ${
                day.dayOfWeek === dow ? 'bg-volt text-ink' : 'bg-surface-2 text-faint'
              }`}
            >
              {letter}
            </button>
          ))}
        </div>
        <p className="mt-2 text-xs text-faint">
          {day.dayOfWeek === null ? 'Tap a day to schedule it.' : 'Tap again to unschedule.'}
        </p>
      </Card>

      <SectionTitle
        action={
          <button
            type="button"
            onClick={() => setPicking(true)}
            className="flex items-center gap-1 text-xs font-bold text-volt"
          >
            <PlusIcon size={15} strokeWidth={2.4} /> Add
          </button>
        }
      >
        Exercises · drag to reorder
      </SectionTitle>

      {day.exercises.length === 0 ? (
        <EmptyState
          icon={<DumbbellIcon size={28} />}
          title="No exercises yet"
          body="Add exercises from the library or create your own."
          action={
            <button type="button" onClick={() => setPicking(true)} className="btn btn-primary h-12 px-6">
              Add exercise
            </button>
          }
        />
      ) : (
        <DragList
          items={day.exercises}
          keyOf={(x) => x.id}
          onReorder={(from, to) => dispatch({ type: 'reorderPlanExercises', dayId: day.id, from, to })}
          renderItem={(item, index, handle, dragging) => (
            <div
              className={`card flex items-stretch overflow-hidden ${dragging ? 'border-volt/60' : ''}`}
              style={{ padding: 0 }}
            >
              <button
                type="button"
                aria-label="Reorder exercise"
                className="flex w-11 shrink-0 items-center justify-center text-faint active:text-chalk"
                {...handle}
              >
                <GripIcon size={20} />
              </button>
              <button
                type="button"
                onClick={() => setEditing(item)}
                className="flex min-w-0 flex-1 items-center gap-3 py-3.5 pr-3.5 text-left"
              >
                <span className="tnum w-5 shrink-0 text-sm font-bold text-faint">{index + 1}</span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-bold">{exerciseName(item.exerciseId)}</span>
                  <span className="tnum mt-0.5 block text-xs text-muted">
                    {item.targetSets} sets × {item.repMin}–{item.repMax} reps
                    {item.notes ? ` · ${item.notes}` : ''}
                  </span>
                </span>
              </button>
            </div>
          )}
        />
      )}

      <button type="button" onClick={() => setPicking(true)} className="btn btn-secondary mt-3 h-12 w-full">
        <PlusIcon size={18} /> Add exercise
      </button>

      {day.exercises.length > 0 && (
        <button type="button" onClick={startThisWorkout} className="btn btn-primary mt-3 h-14 w-full tracking-wide">
          <PlayIcon size={18} /> START THIS WORKOUT
        </button>
      )}

      <ExercisePicker open={picking} onClose={() => setPicking(false)} onPick={addExercise} />

      <Sheet open={editing !== null} onClose={() => setEditing(null)} title={editing ? exerciseName(editing.exerciseId) : ''}>
        {editing && (
          <div className="flex flex-col gap-5">
            <NumberStepper
              label="Target sets"
              value={editing.targetSets}
              min={1}
              max={20}
              onChange={(v) => patchExercise(editing.id, { targetSets: v })}
            />
            <div className="flex gap-3">
              <NumberStepper
                label="Min reps"
                value={editing.repMin}
                min={1}
                max={100}
                onChange={(v) => patchExercise(editing.id, { repMin: v, repMax: Math.max(v, editing.repMax) })}
              />
              <NumberStepper
                label="Max reps"
                value={editing.repMax}
                min={1}
                max={100}
                onChange={(v) => patchExercise(editing.id, { repMax: Math.max(v, editing.repMin) })}
              />
            </div>
            <div>
              <label className="label-caps" htmlFor="ex-notes">
                Notes
              </label>
              <textarea
                id="ex-notes"
                rows={3}
                value={editing.notes ?? ''}
                onChange={(e) => patchExercise(editing.id, { notes: e.target.value })}
                placeholder="Seat height 4, slow eccentric…"
                className="field mt-2 resize-none"
              />
            </div>
            <button
              type="button"
              onClick={() => {
                dispatch({ type: 'deletePlanExercise', dayId: day.id, planId: editing.id });
                setEditing(null);
              }}
              className="btn btn-ghost h-12 w-full text-danger"
            >
              <TrashIcon size={18} /> Remove exercise
            </button>
          </div>
        )}
      </Sheet>

      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title="Delete this day?">
        <p className="text-sm text-muted">
          “{day.name}” and its {day.exercises.length} exercises will be removed from your split. Logged workouts
          stay in your history.
        </p>
        <div className="mt-5 flex gap-3">
          <button type="button" onClick={() => setConfirmDelete(false)} className="btn btn-secondary h-12 flex-1">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              dispatch({ type: 'deleteDay', dayId: day.id });
              navigate('/builder');
            }}
            className="btn h-12 flex-1 bg-danger text-ink"
          >
            Delete
          </button>
        </div>
      </Sheet>
    </Screen>
  );
}
