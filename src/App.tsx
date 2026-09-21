import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useStore } from './state/store';
import { TimerProvider } from './state/timer';
import BottomNav from './components/BottomNav';
import RestTimerBar from './components/RestTimerBar';
import Onboarding from './pages/Onboarding';
import Home from './pages/Home';
import Builder from './pages/Builder';
import DayEditor from './pages/DayEditor';
import Workout from './pages/Workout';
import History from './pages/History';
import SessionDetail from './pages/SessionDetail';
import Progress from './pages/Progress';
import ExerciseDetail from './pages/ExerciseDetail';
import Records from './pages/Records';
import Settings from './pages/Settings';

export default function App() {
  const { state } = useStore();
  const location = useLocation();
  const setupRoute = location.pathname === '/setup';

  if (!state.onboarded && !setupRoute) return <Navigate to="/setup" replace />;

  return (
    <TimerProvider soundOn={state.settings.soundOn}>
      <div className="min-h-full">
        <Routes>
          <Route path="/setup" element={<Onboarding />} />
          <Route path="/" element={<Home />} />
          <Route path="/builder" element={<Builder />} />
          <Route path="/builder/day/:dayId" element={<DayEditor />} />
          <Route path="/workout" element={<Workout />} />
          <Route path="/history" element={<History />} />
          <Route path="/history/:sessionId" element={<SessionDetail />} />
          <Route path="/progress" element={<Progress />} />
          <Route path="/progress/exercise/:exerciseId" element={<ExerciseDetail />} />
          <Route path="/records" element={<Records />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
        {!setupRoute && (
          <>
            <RestTimerBar />
            <BottomNav />
          </>
        )}
      </div>
    </TimerProvider>
  );
}
