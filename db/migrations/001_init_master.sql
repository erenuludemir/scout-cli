\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

-- run as superuser (brew macOS: current user)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='qaiuser') THEN
    CREATE ROLE qaiuser LOGIN PASSWORD 'qaipass';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='qai') THEN
    CREATE DATABASE qai OWNER qaiuser;
  END IF;
END$$;

\connect :DBNAME

SET client_min_messages TO WARNING;
BEGIN;
SELECT pg_advisory_lock(93841234);

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER SCHEMA public OWNER TO qaiuser;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT 'TABLE '||quote_ident(schemaname)||'.'||quote_ident(tablename) AS obj
             FROM pg_tables WHERE schemaname='public'
  LOOP EXECUTE 'ALTER '||r.obj||' OWNER TO qaiuser'; END LOOP;

  FOR r IN SELECT 'SEQUENCE '||quote_ident(schemaname)||'.'||quote_ident(sequencename) AS obj
             FROM pg_sequences WHERE schemaname='public'
  LOOP EXECUTE 'ALTER '||r.obj||' OWNER TO qaiuser'; END LOOP;
END$$;

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE TABLE IF NOT EXISTS accounts (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  asset TEXT NOT NULL,
  balance NUMERIC(32,8) NOT NULL DEFAULT 0
);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='uc_user_asset' AND conrelid='accounts'::regclass
  ) THEN
    ALTER TABLE accounts ADD CONSTRAINT uc_user_asset UNIQUE(user_id, asset);
  END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_accounts_user  ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_asset ON accounts(asset);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='order_side') THEN
    CREATE TYPE order_side AS ENUM('BUY','SELL');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  market TEXT NOT NULL,
  side order_side NOT NULL,
  price NUMERIC(32,8) NOT NULL CHECK (price > 0),
  qty   NUMERIC(32,8) NOT NULL CHECK (qty > 0),
  status TEXT NOT NULL DEFAULT 'OPEN',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_orders_user          ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_market_side   ON orders(market, side);
CREATE INDEX IF NOT EXISTS idx_orders_status_market ON orders(status, market);
CREATE INDEX IF NOT EXISTS idx_orders_created_at    ON orders(created_at);

CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  buy_order_id  BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  sell_order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  market TEXT NOT NULL,
  price NUMERIC(32,8) NOT NULL,
  qty   NUMERIC(32,8) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_trades_market_time ON trades(market, created_at DESC);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='touch_updated_at') THEN
    CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $f$
    BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $f$ LANGUAGE plpgsql;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE event_object_table='orders' AND trigger_name='trg_orders_updated_at'
  ) THEN
    CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
      FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS schema_migrations(
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT NOW()
);
INSERT INTO schema_migrations(version)
  SELECT '001_init_master'
  WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version='001_init_master');

SELECT pg_advisory_unlock(93841234);
COMMIT;
