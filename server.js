const express = require('express');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
app.use(helmet());
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));

// Halaman utama
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="id">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Platform Donasi Bencana Daerah</title>
      <style>
        * { box-sizing: border-box; }
        body {
          margin: 0;
          font-family: Arial, sans-serif;
          background: #f1f5f9;
          color: #1e293b;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 24px;
        }
        main {
          max-width: 650px;
          width: 100%;
          background: white;
          padding: 45px 30px;
          border-radius: 16px;
          text-align: center;
          box-shadow: 0 8px 30px rgba(0,0,0,.07);
        }
        h1 { color: #0f766e; margin-bottom: 15px; }
        p { line-height: 1.7; color: #475569; }
        .status {
          display: inline-block;
          margin-top: 15px;
          padding: 9px 16px;
          border-radius: 30px;
          background: #dcfce7;
          color: #166534;
          font-size: 14px;
          font-weight: bold;
        }
      </style>
    </head>
    <body>
      <main>
        <h1>Platform Donasi Bencana Daerah</h1>
        <p>
          Platform ini menyediakan layanan informasi dan pengelolaan
          donasi untuk membantu masyarakat terdampak bencana daerah.
        </p>
        <div class="status">● Sistem Berjalan</div>
        <p>Platform Donasi Bencana Daerah</p>
      </main>
    </body>
    </html>
  `);
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use(require('./routes/campaigns'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`App on port ${PORT}`));
