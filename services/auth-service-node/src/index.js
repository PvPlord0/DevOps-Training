require('dotenv').config();
const express = require('express');
const authRoutes = require('./routes/auth');
const { init } = require('./db');

const app = express();
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api/auth', authRoutes);

const port = process.env.PORT || 8082;

init()
  .then(() => {
    app.listen(port, () => console.log(`auth-service listening on ${port}`));
  })
  .catch((err) => {
    console.error('failed to initialize database', err);
    process.exit(1);
  });
