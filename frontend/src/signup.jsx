import { useState } from 'react';
import { api } from './api';

export default function Signup({ onSignup }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await api.register(email, password);
      onSignup();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div >
      <h1>Signup</h1>
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
        <button type="submit">Signup</button>
      </form>
    </div>
  );
}