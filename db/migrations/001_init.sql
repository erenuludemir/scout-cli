CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounts (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  asset TEXT NOT NULL,
  balance NUMERIC(32,8) NOT NULL DEFAULT 0,
  CONSTRAINT uc_user_asset UNIQUE(user_id, asset)
);

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  market TEXT NOT NULL,
  side TEXT NOT NULL CHECK (side IN (''BUY'',''SELL'')),
  price NUMERIC(32,8) NOT NULL,
  qty   NUMERIC(32,8) NOT NULL,
  status TEXT NOT NULL DEFAULT ''OPEN'',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  buy_order_id  BIGINT REFERENCES orders(id),
  sell_order_id BIGINT REFERENCES orders(id),
  market TEXT NOT NULL,
  price  NUMERIC(32,8) NOT NULL,
  qty    NUMERIC(32,8) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
