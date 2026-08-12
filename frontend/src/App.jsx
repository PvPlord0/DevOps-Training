import { useEffect, useState } from 'react';
import { api, setAuthToken, getAuthToken, clearAuthToken } from './api';
import Dashboard from './Dashboard';

function decodeToken(token) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(atob(parts[1]));
  } catch {
    return null;
  }
}

export default function App() {
  const [tab, setTab] = useState('catalog');
  const [catalog, setCatalog] = useState([]);
  const [error, setError] = useState(null);
  const [user, setUser] = useState(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [authError, setAuthError] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const token = getAuthToken();
    if (token) {
      const payload = decodeToken(token);
      if (!payload) {
        clearAuthToken();
      } else if (payload.exp && payload.exp * 1000 < Date.now()) {
        clearAuthToken();
        setAuthError('Session expired. Please log in again.');
      } else {
        setUser({ id: payload.sub, email: payload.email });
      }
    }
  }, []);

  useEffect(() => {
    if (user) {
      api.catalog().then(setCatalog).catch((err) => setError(err.message));
    }
  }, [user]);

  async function handleLogin(e) {
    e.preventDefault();
    setLoading(true);
    setAuthError(null);
    try {
      const { token } = await api.login(email, password);
      const payload = decodeToken(token);
      if (!payload) throw new Error('Invalid token received');
      if (payload.exp && payload.exp * 1000 < Date.now()) throw new Error('Token is expired');
      setAuthToken(token);
      setUser({ id: payload.sub, email: payload.email });
    } catch (err) {
      setAuthError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleRegister(e) {
    e.preventDefault();
    setLoading(true);
    setAuthError(null);
    try {
      await api.register(email, password);
      const { token } = await api.login(email, password);
      const payload = decodeToken(token);
      if (!payload) throw new Error('Invalid token received');
      if (payload.exp && payload.exp * 1000 < Date.now()) throw new Error('Token is expired');
      setAuthToken(token);
      setUser({ id: payload.sub, email: payload.email });
    } catch (err) {
      setAuthError(err.message);
    } finally {
      setLoading(false);
    }
  }

  function handleLogout() {
    clearAuthToken();
    setUser(null);
    setCatalog([]);
    setEmail('');
    setPassword('');
  }

  if (!user) {
    return (
      <div style={{ fontFamily: 'sans-serif', padding: '2rem', maxWidth: 400 }}>
        <h1>EventHub</h1>
        <form onSubmit={handleLogin}>
          <h2>Login</h2>
          {authError && <p style={{ color: 'crimson' }}>{authError}</p>}
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            style={{ display: 'block', marginBottom: '0.5rem', padding: '0.5rem', width: '100%' }}
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            style={{ display: 'block', marginBottom: '0.5rem', padding: '0.5rem', width: '100%' }}
          />
          <button type="submit" disabled={loading} style={{ marginRight: '0.5rem' }}>
            {loading ? 'Loading...' : 'Login'}
          </button>
          <button type="button" onClick={handleRegister} disabled={loading}>
            Register
          </button>
        </form>
      </div>
    );
  }

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>EventHub</h1>
      </div>

      <div style={{ marginBottom: '1rem' }}>
        <button onClick={() => setTab('catalog')} disabled={tab === 'catalog'}>
          Catalog
        </button>{' '}
        <button onClick={() => setTab('dashboard')} disabled={tab === 'dashboard'}>
          Dashboard
        </button>{' '}
        <button onClick={() => setTab('analyze')} disabled={tab === 'analyze'}>
          Analyze
        </button>{' '}
        <button onClick={() => setTab('profile')} disabled={tab === 'profile'}>
          Profile
        </button>
      </div>

      {tab === 'catalog' && (
        <CatalogView catalog={catalog} error={error} user={user} />
      )}

      {tab === 'dashboard' && <Dashboard />}

      {tab === 'analyze' && <AnalyzeView />}

      {tab === 'profile' && <ProfileView user={user} onLogout={handleLogout} />}
    </div>
  );
}

function CatalogView({ catalog, error, user }) {
  const [bookingEventId, setBookingEventId] = useState(null);
  const [bookedEvents, setBookedEvents] = useState(new Set());
  const [bookingIds, setBookingIds] = useState({});
  const [reviewEventId, setReviewEventId] = useState(null);
  const [reviewText, setReviewText] = useState('');
  const [message, setMessage] = useState(null);

  async function handleBook(eventId) {
    setBookingEventId(eventId);
    setMessage(null);
    try {
      const response = await api.book(String(user.id), eventId);
      setBookedEvents((prev) => new Set([...prev, eventId]));
      setBookingIds((prev) => ({ ...prev, [eventId]: response.bookingId || response.id || response.booking_id }));
      setMessage({ type: 'success', text: 'Booked successfully!' });
    } catch (err) {
      setMessage({ type: 'error', text: err.message });
    } finally {
      setBookingEventId(null);
    }
  }

  async function handleReview(eventId) {
    setMessage(null);
    try {
      await api.review(bookingIds[eventId], reviewText);
      setMessage({ type: 'success', text: 'Review submitted!' });
      setReviewEventId(null);
      setReviewText('');
    } catch (err) {
      setMessage({ type: 'error', text: err.message });
    }
  }

  return (
    <div>
      {error && <p style={{ color: 'crimson' }}>Failed to load catalog: {error}</p>}
      {message && (
        <p style={{ color: message.type === 'success' ? 'green' : 'crimson' }}>{message.text}</p>
      )}
      <ul>
        {catalog.map((event) => (
          <li key={event.id} style={{ marginBottom: '1rem' }}>
            <strong>{event.title}</strong> - ${event.price}
            <br />
            {!bookedEvents.has(event.id) ? (
              <button
                onClick={() => handleBook(event.id)}
                disabled={bookingEventId === event.id}
                style={{ marginTop: '0.25rem' }}
              >
                {bookingEventId === event.id ? 'Booking...' : 'Book'}
              </button>
            ) : (
              <span style={{ color: 'green' }}>Booked</span>
            )}
            {bookedEvents.has(event.id) && (
              <div style={{ marginTop: '0.5rem' }}>
                {reviewEventId === event.id ? (
                  <div>
                    <textarea
                      value={reviewText}
                      onChange={(e) => setReviewText(e.target.value)}
                      placeholder="Write your review..."
                      style={{ width: '100%', height: 60 }}
                    />
                    <button onClick={() => handleReview(event.id)} style={{ marginRight: '0.5rem' }}>
                      Submit
                    </button>
                    <button onClick={() => { setReviewEventId(null); setReviewText(''); }}>Cancel</button>
                  </div>
                ) : (
                  <button onClick={() => setReviewEventId(event.id)}>Add Review</button>
                )}
              </div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

function ProfileView({ user, onLogout }) {
  return (
    <div>
      <h2>Profile</h2>
      <p><strong>Email:</strong> {user.email}</p>
      <button onClick={onLogout} style={{ backgroundColor: 'crimson', color: 'white', border: 'none', padding: '0.5rem 1rem', cursor: 'pointer' }}>
        Logout
      </button>
    </div>
  );
}

function AnalyzeView() {
  const [text, setText] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleAnalyze(e) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const data = await api.analyze(text);
      setResult(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h2>Sentiment Analyzer</h2>
      <form onSubmit={handleAnalyze}>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Enter text to analyze..."
          required
          style={{ width: '100%', height: 100, marginBottom: '0.5rem' }}
        />
        <button type="submit" disabled={loading}>
          {loading ? 'Analyzing...' : 'Analyze'}
        </button>
      </form>
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      {result && (
        <div style={{ marginTop: '1rem', padding: '1rem', border: '1px solid #ccc' }}>
          <p><strong>Sentiment:</strong> {result.sentiment}</p>
          {result.summary && <p><strong>Summary:</strong> {result.summary}</p>}
          {result.score !== undefined && <p><strong>Score:</strong> {result.score}</p>}
        </div>
      )}
    </div>
  );
}
