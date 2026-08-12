import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import Login from './login.jsx';
import Signup from './signup.jsx';
import { clearAuthToken, getAuthToken } from './api';

function AuthGate() {
  const [isAuthenticated, setIsAuthenticated] = React.useState(() => Boolean(getAuthToken()));
  const [mode, setMode] = React.useState('login');

  const handleAuthSuccess = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    clearAuthToken();
    setIsAuthenticated(false);
    setMode('login');
  };

  if (isAuthenticated) {
    return <App onLogout={handleLogout} />;
  }

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <div style={{ marginBottom: '1rem' }}>
        <button type="button" onClick={() => setMode('login')} disabled={mode === 'login'}>
          Login
        </button>{' '}
        <button type="button" onClick={() => setMode('signup')} disabled={mode === 'signup'}>
          Signup
        </button>
      </div>

      {mode === 'login' ? (
        <Login onLogin={handleAuthSuccess} />
      ) : (
        <Signup onSignup={handleAuthSuccess} />
      )}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(
  //adding the login/signup page to the main.jsx file so that it can be rendered in the browser
  <React.StrictMode>
    <AuthGate />
  </React.StrictMode>
);
