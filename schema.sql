CREATE TABLE IF NOT EXISTS campaigns (
  id SERIAL PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  region VARCHAR(100) NOT NULL,
  disaster_type VARCHAR(50) NOT NULL,
  target_amount NUMERIC(14,2) NOT NULL CHECK (target_amount > 0),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS donations (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id),
  donor_name VARCHAR(100) NOT NULL,
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  message VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_campaign ON donations(campaign_id);

-- data awal untuk uji
INSERT INTO campaigns (title, region, disaster_type, target_amount, status) VALUES
  ('Bantuan Korban Banjir Sintang', 'Sintang', 'Banjir', 150000000, 'active'),
  ('Pemulihan Lahan Terbakar Kubu Raya', 'Kubu Raya', 'Kebakaran lahan', 80000000, 'active'),
  ('Logistik Pengungsi Banjir Kapuas Hulu', 'Kapuas Hulu', 'Banjir', 120000000, 'active'),
  ('Rehabilitasi Rumah Terdampak Longsor', 'Ketapang', 'Longsor', 60000000, 'closed');

INSERT INTO donations (campaign_id, donor_name, amount, message) VALUES
  (1, 'Budi Santoso', 250000, 'Semoga cepat pulih'),
  (1, 'Siti Aminah', 500000, NULL),
  (2, 'Andi Wijaya', 100000, 'Semangat warga Kubu Raya'),
  (3, 'Dewi Lestari', 750000, NULL);
