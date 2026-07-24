from pathlib import Path
import sys

import duckdb


if len(sys.argv) != 2:
    raise SystemExit("Usage: generate_duckdb_fixture.py <workspace>")

workspace = Path(sys.argv[1]).resolve()
workspace.mkdir(parents=True, exist_ok=True)

database = workspace / "STANDALONE_DBCODE_PROOF.duckdb"
parquet = workspace / "STANDALONE_DBCODE_PROOF.parquet"

connection = duckdb.connect(str(database))
connection.execute(
    """
    CREATE OR REPLACE TABLE persistent_proof AS
    SELECT * FROM (VALUES
        (1, 'duckdb-alpha', 10.25),
        (2, 'duckdb-beta', 20.50),
        (3, 'duckdb-gamma', 30.75)
    ) AS rows(id, label, amount)
    """
)
connection.execute(
    "COPY persistent_proof TO ? (FORMAT PARQUET)",
    [str(parquet)],
)
connection.close()

sql_path = str(parquet).replace("'", "''")
(workspace / "duckdb-parquet-proof.sql").write_text(
    """SELECT id, label, amount
FROM persistent_proof
ORDER BY id;

SELECT id, label, amount
FROM read_parquet('{parquet_path}')
ORDER BY id;
""".format(parquet_path=sql_path),
    encoding="utf-8",
)

print(f"DuckDB: {database}")
print(f"Parquet: {parquet}")
