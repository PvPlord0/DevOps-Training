import { useEffect, useState } from 'react';
import { api } from './api';
import Dashboard from './Dashboard';

export default function App() {
  const [tab, setTab] = useState('catalog');
  const [catalog, setCatalog] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    api.catalog().then(setCatalog).catch((err) => setError(err.message));
  }, []);

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>EventHub</h1>

      <div style={{ marginBottom: '1rem' }}>
        <button onClick={() => setTab('catalog')} disabled={tab === 'catalog'}>
          Catalog
        </button>{' '}
        <button onClick={() => setTab('dashboard')} disabled={tab === 'dashboard'}>
          Dashboard
        </button>
      </div>

      {tab === 'catalog' && (
        <div>
          {error && <p style={{ color: 'crimson' }}>Failed to load catalog: {error}</p>}
          <ul>
            {catalog.map((event) => (
              <li key={event.id}>
                {event.title} - ${event.price}
              </li>
            ))}
          </ul>
        </div>
      )}

      {tab === 'dashboard' && <Dashboard />}
    </div>
  );
}
