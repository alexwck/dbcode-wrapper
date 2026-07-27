SHOW shared_preload_libraries;

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pldbgapi';

SELECT
    routine_schema,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'debugger_proof'
  AND routine_name = 'calculate_total';

SELECT debugger_proof.calculate_total(5, 3) AS expected_result_22;
