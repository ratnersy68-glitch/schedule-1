import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, HashRouter } from 'react-router-dom';
import App from './App';
import { StoreProvider } from './state/store';
import './index.css';

// Hosts that cannot rewrite unknown paths to index.html (static sub-path hosting,
// file://) can be built with VITE_ROUTER=hash so deep links keep working.
const Router = import.meta.env.VITE_ROUTER === 'hash' ? HashRouter : BrowserRouter;

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Router>
      <StoreProvider>
        <App />
      </StoreProvider>
    </Router>
  </StrictMode>
);

if ('serviceWorker' in navigator && import.meta.env.PROD && import.meta.env.VITE_ROUTER !== 'hash') {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      /* offline support is optional */
    });
  });
}
