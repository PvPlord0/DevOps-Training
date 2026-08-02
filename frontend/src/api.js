const BASE_URL =
  (typeof window !== 'undefined' && window.__ENV__ && window.__ENV__.API_BASE_URL) ||
  import.meta.env.VITE_API_BASE_URL ||
  'http://localhost:8080';

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options,
  });
  if (!res.ok) {
    throw new Error(`${options.method || 'GET'} ${path} failed: ${res.status}`);
  }
  return res.json();
}

export const api = {
  login: (email, password) =>
    request('/api/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),
  register: (email, password) =>
    request('/api/auth/register', { method: 'POST', body: JSON.stringify({ email, password }) }),
  catalog: () => request('/api/catalog'),
  book: (userId, eventId) =>
    request('/api/bookings', { method: 'POST', body: JSON.stringify({ userId, eventId }) }),
  analyze: (text) =>
    request('/api/analyze', { method: 'POST', body: JSON.stringify({ text }) }),
  review: (bookingId, text) =>
    request(`/api/bookings/${bookingId}/review`, { method: 'POST', body: JSON.stringify({ text }) }),
  analyticsSummary: () => request('/api/analytics/summary'),
};
