const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');
const { pool } = require('../db');

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

const privateKey = loadKeyFromFile(process.env.JWT_PRIVATE_KEY_PATH);

const router = express.Router();

router.post('/register', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email',
      [email, hash]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'email already registered' });
    }
    res.status(500).json({ error: 'internal error' });
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];
    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ error: 'invalid credentials' });
    }

    const token = jwt.sign(
      { sub: user.id, email: user.email },
      privateKey,
      { algorithm: 'RS256', expiresIn: '2h' }
    );
    res.json({ token });
  } catch (err) {
    res.status(500).json({ error: 'internal error' });
  }
});

module.exports = router;
