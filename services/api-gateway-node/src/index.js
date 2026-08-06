require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
app.use(cors({ origin: process.env.FRONTEND_URL || 'http://localhost:3000' }));

const routes = {
  '/api/catalog': 'http://localhost:8081',
  '/api/auth': 'http://localhost:8082',
  '/api/bookings': 'http://localhost:8083',
  '/api/analyze': 'http://localhost:8084',
  '/api/analytics': 'http://localhost:8085',
};

Object.entries(routes).forEach(([path, target]) => {
  app.use(path, createProxyMiddleware({
    target,
    changeOrigin: true,
  }));
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`api-gateway listening on ${port}`));
