import { useEffect, useMemo, useState } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend,
} from 'recharts';
import { api } from './api';

const SENTIMENT_COLORS = { positive: '#1D9E75', neutral: '#888780', negative: '#D85A30' };

export default function Dashboard() {
  const [snapshot, setSnapshot] = useState(null);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [sortKey, setSortKey] = useState('bookingsCount');
  const [sortDir, setSortDir] = useState('desc');

  useEffect(() => {
    api.analyticsSummary().then(setSnapshot).catch((err) => setError(err.message));
  }, []);

  const rows = useMemo(() => {
    if (!snapshot) return [];
    const filtered = snapshot.eventsTable.filter((row) =>
      row.title.toLowerCase().includes(search.toLowerCase())
    );
    return [...filtered].sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1;
      return a[sortKey] > b[sortKey] ? dir : a[sortKey] < b[sortKey] ? -dir : 0;
    });
  }, [snapshot, search, sortKey, sortDir]);

  function toggleSort(key) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('desc');
    }
  }

  if (error) {
    return <p style={{ color: 'crimson' }}>Failed to load analytics: {error}</p>;
  }
  if (!snapshot) {
    return <p>Loading analytics...</p>;
  }

  const sentimentData = Object.entries(snapshot.sentimentTotals).map(([name, value]) => ({
    name,
    value,
  }));

  const columns = [
    ['title', 'Event'],
    ['bookingsCount', 'Bookings'],
    ['revenue', 'Revenue'],
    ['reviewCount', 'Reviews'],
    ['avgSentimentScore', 'Avg sentiment'],
  ];

  return (
    <div>
      <p style={{ color: '#888' }}>
        Last generated: {new Date(snapshot.generatedAt).toLocaleString()}
      </p>

      <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
        <div style={{ flex: '1 1 320px', height: 260 }}>
          <h3>Bookings over time</h3>
          <ResponsiveContainer width="100%" height="90%">
            <LineChart data={snapshot.bookingsTimeseries}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" tick={{ fontSize: 11 }} />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Line type="monotone" dataKey="bookings" stroke="#378ADD" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div style={{ flex: '1 1 260px', height: 260 }}>
          <h3>Review sentiment</h3>
          <ResponsiveContainer width="100%" height="90%">
            <PieChart>
              <Pie data={sentimentData} dataKey="value" nameKey="name" outerRadius={80}>
                {sentimentData.map((entry) => (
                  <Cell key={entry.name} fill={SENTIMENT_COLORS[entry.name] || '#888'} />
                ))}
              </Pie>
              <Legend />
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      <h3>Events</h3>
      <input
        placeholder="Filter by event title..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: '0.5rem', padding: '0.25rem 0.5rem' }}
      />
      <table style={{ borderCollapse: 'collapse', width: '100%' }}>
        <thead>
          <tr>
            {columns.map(([key, label]) => (
              <th
                key={key}
                onClick={() => toggleSort(key)}
                style={{ cursor: 'pointer', textAlign: 'left', borderBottom: '1px solid #ccc', padding: '0.4rem' }}
              >
                {label}{sortKey === key ? (sortDir === 'asc' ? ' ^' : ' v') : ''}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.eventId}>
              <td style={{ padding: '0.4rem', borderBottom: '1px solid #eee' }}>{row.title}</td>
              <td style={{ padding: '0.4rem', borderBottom: '1px solid #eee' }}>{row.bookingsCount}</td>
              <td style={{ padding: '0.4rem', borderBottom: '1px solid #eee' }}>${row.revenue}</td>
              <td style={{ padding: '0.4rem', borderBottom: '1px solid #eee' }}>{row.reviewCount}</td>
              <td style={{ padding: '0.4rem', borderBottom: '1px solid #eee' }}>{row.avgSentimentScore}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {rows.length === 0 && <p>No events match your filter.</p>}
    </div>
  );
}
