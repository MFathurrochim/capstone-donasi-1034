const router = require('express').Router();
const pool = require('../db');

// GET: daftar kampanye + total donasi terkumpul (agregasi, lebih berat dari select biasa)
router.get('/api/campaigns', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT c.id, c.title, c.region, c.disaster_type, c.target_amount, c.status, c.created_at,
              COALESCE(SUM(d.amount), 0) AS collected_amount,
              COUNT(d.id) AS donor_count
       FROM campaigns c
       LEFT JOIN donations d ON d.campaign_id = c.id
       GROUP BY c.id
       ORDER BY c.id`
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST: catat donasi baru (validasi input + cek kampanye aktif + hitung ulang total)
router.post('/api/donations', async (req, res) => {
  const { campaign_id, donor_name, amount, message } = req.body || {};
  const campaignId = Number.parseInt(campaign_id, 10);
  const value = Number(amount);

  if (!Number.isInteger(campaignId) || campaignId <= 0) {
    return res.status(400).json({ error: 'campaign_id tidak valid' });
  }
  if (typeof donor_name !== 'string' || !donor_name.trim() || donor_name.length > 100) {
    return res.status(400).json({ error: 'donor_name wajib diisi (maks 100 karakter)' });
  }
  if (!Number.isFinite(value) || value < 1000 || value > 1000000000) {
    return res.status(400).json({ error: 'amount harus antara 1.000 dan 1.000.000.000' });
  }
  if (message !== undefined && (typeof message !== 'string' || message.length > 255)) {
    return res.status(400).json({ error: 'message maksimal 255 karakter' });
  }

  try {
    const campaign = await pool.query(
      'SELECT status FROM campaigns WHERE id = $1', [campaignId]
    );
    if (!campaign.rows[0]) {
      return res.status(404).json({ error: 'Kampanye tidak ditemukan' });
    }
    if (campaign.rows[0].status !== 'active') {
      return res.status(409).json({ error: 'Kampanye sudah ditutup' });
    }

    const { rows } = await pool.query(
      `INSERT INTO donations (campaign_id, donor_name, amount, message)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [campaignId, donor_name.trim(), value, message || null]
    );

    const total = await pool.query(
      'SELECT COALESCE(SUM(amount), 0) AS collected_amount FROM donations WHERE campaign_id = $1',
      [campaignId]
    );

    res.status(201).json({ donation: rows[0], collected_amount: total.rows[0].collected_amount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
