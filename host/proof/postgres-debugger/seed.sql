\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pldbgapi;

DO $role$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbcode_debugger') THEN
        CREATE ROLE dbcode_debugger
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION;
    END IF;
END
$role$;

ALTER ROLE dbcode_debugger
    WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

GRANT CONNECT ON DATABASE dbcode_debugger_proof TO dbcode_debugger;

CREATE SCHEMA IF NOT EXISTS debugger_proof AUTHORIZATION dbcode_debugger;
ALTER SCHEMA debugger_proof OWNER TO dbcode_debugger;
REVOKE ALL ON SCHEMA debugger_proof FROM PUBLIC;
GRANT USAGE ON SCHEMA debugger_proof TO dbcode_debugger;

CREATE OR REPLACE FUNCTION debugger_proof.calculate_total(
    base_value integer,
    multiplier integer
)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    multiplied_value integer := base_value * multiplier;
    adjustment integer := 7;
    final_total integer;
BEGIN
    final_total := multiplied_value + adjustment;
    RETURN final_total;
END
$function$;

ALTER FUNCTION debugger_proof.calculate_total(integer, integer) OWNER TO dbcode_debugger;
REVOKE ALL ON FUNCTION debugger_proof.calculate_total(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION debugger_proof.calculate_total(integer, integer) TO dbcode_debugger;
