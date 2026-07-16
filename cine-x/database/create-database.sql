-- Run with psql as a PostgreSQL superuser.
-- Example:
-- psql -U postgres -f database/create-database.sql

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cinex') THEN
        CREATE ROLE cinex LOGIN PASSWORD 'cinex_local_2026';
    END IF;
END $$;

SELECT 'CREATE DATABASE cinexdb OWNER cinex'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'cinexdb')\gexec
