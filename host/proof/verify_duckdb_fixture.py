import json
from decimal import Decimal
from pathlib import Path
import sys

import duckdb


if len(sys.argv) != 2:
    raise SystemExit("Usage: verify_duckdb_fixture.py <workspace>")

workspace = Path(sys.argv[1]).resolve()
database = workspace / "STANDALONE_DBCODE_PROOF.duckdb"
parquet = workspace / "STANDALONE_DBCODE_PROOF.parquet"
expected = [
    (1, "duckdb-alpha", Decimal("10.25")),
    (2, "duckdb-beta", Decimal("20.50")),
    (3, "duckdb-gamma", Decimal("30.75")),
]

connection = duckdb.connect(str(database), read_only=True)
try:
    duckdb_rows = connection.execute(
        "SELECT id, label, amount FROM persistent_proof ORDER BY id"
    ).fetchall()
    parquet_rows = connection.execute(
        "SELECT id, label, amount FROM read_parquet(?) ORDER BY id",
        [str(parquet)],
    ).fetchall()
finally:
    connection.close()

if duckdb_rows != expected:
    raise SystemExit("The persistent DuckDB proof rows do not match the expected fixture.")
if parquet_rows != expected:
    raise SystemExit("The direct Parquet proof rows do not match the expected fixture.")

summary = {
    "row_count": len(expected),
    "amount_sum": format(sum((row[2] for row in expected), Decimal("0")), ".2f"),
    "first_id": expected[0][0],
    "last_id": expected[-1][0],
}
print(json.dumps({"duckdb": summary, "parquet": summary}, sort_keys=True))
