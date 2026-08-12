import { useState } from 'react';
import { api, setAuthToken } from './api';

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const result = await api.login(email, password);
      setAuthToken(result.token);
      onLogin();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div style={{ fontFamily: 'sans-serif'}}>
      <h1>Login</h1>
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      <form onSubmit={handleSubmit}>
        <div>
          <label>
            Email:
            <input style={{marginBottom: '1rem'}}
              type="text"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </label>
        </div>
        <div>
          <label>
            Password:
            <input style={{marginBottom: '1rem'}}
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
        </div>
        <button type="submit">Login</button>
      </form>
    </div>
  );
}

