const express = require('express');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"]
    }
  }
}));
app.use(express.json({ limit: '10kb' }));
app.use(express.static('public'));

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use(require('./routes/campaigns'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`App on port ${PORT}`));
