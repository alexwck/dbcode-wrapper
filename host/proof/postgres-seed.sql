\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS public.proof_items (
    id integer PRIMARY KEY,
    label text NOT NULL,
    amount numeric(10, 2) NOT NULL
);

TRUNCATE TABLE public.proof_items;

INSERT INTO public.proof_items (id, label, amount) VALUES
    (1, 'postgres-alpha', 12.50),
    (2, 'postgres-beta', 25.00),
    (3, 'postgres-gamma', 37.50);

DO $proof$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbcode_reader') THEN
        CREATE ROLE dbcode_reader LOGIN PASSWORD 'dbcode-readonly';
    END IF;
END
$proof$;

ALTER ROLE dbcode_reader
    WITH LOGIN PASSWORD 'dbcode-readonly'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
ALTER ROLE dbcode_reader SET default_transaction_read_only = on;

GRANT CONNECT ON DATABASE dbcode_proof TO dbcode_reader;
GRANT USAGE ON SCHEMA public TO dbcode_reader;
GRANT SELECT ON TABLE public.proof_items TO dbcode_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbcode_reader;
