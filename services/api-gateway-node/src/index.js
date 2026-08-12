require('dotenv').config();
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

function loadKeyFromFile(filePath) {
  if (!filePath) {
    throw new Error('File path is required');
  }

  try {
    const key = fs.readFileSync(path.resolve(filePath), 'utf8').trim();
    if (!key) throw new Error('File is empty');
    return key;
  } catch (err) {
    throw new Error(`Failed to load file: ${err.message}`);
  }
}

const app = express();
app.use(cors({ origin: process.env.FRONTEND_URL || 'http://localhost:3000' }));

const publicKey = loadKeyFromFile(process.env.JWT_PUBLIC_KEY_PATH);

const routes = {
  '/api/catalog': 'http://localhost:8081',
  '/api/auth': 'http://localhost:8082',
  '/api/bookings': 'http://localhost:8083',
  '/api/reviews': 'http://localhost:8083',
  '/api/analyze': 'http://localhost:8084',
  '/api/analytics': 'http://localhost:8085',
};

function skipAuth(req) {
  return req.path === '/health' || req.path.startsWith('/api/auth');
}

function authenticate(req, res, next) {
  if (skipAuth(req)) return next();

  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'missing token' });
  }

  const token = auth.slice(7);
  try {
    req.user = jwt.verify(token, publicKey, { algorithms: ['RS256'] });
    forwardUserHeaders(req);
    next();
  } catch {
    return res.status(401).json({ error: 'invalid token' });
  }
}

function forwardUserHeaders(req) {
  req.headers['x-user-id'] = req.user.sub;
  req.headers['x-user-email'] = req.user.email;
}

function setupRoutes(app) {
  Object.entries(routes).forEach(([path, target]) => {
    app.use(path, createProxyMiddleware({ target, changeOrigin: true }));
  });
}

app.use(authenticate);
setupRoutes(app);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`api-gateway listening on ${port}`));
