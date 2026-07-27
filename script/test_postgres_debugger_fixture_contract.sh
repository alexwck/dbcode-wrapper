#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

fixture_root="${REPO_ROOT}/host/proof/postgres-debugger"
containerfile="${fixture_root}/Containerfile"
seed_sql="${fixture_root}/seed.sql"
proof_sql="${fixture_root}/postgres-debugger-proof.sql"
fixture_module="${REPO_ROOT}/script/lib/postgres_debugger_fixture.sh"
proof_harness="${REPO_ROOT}/script/proof_dbcode.sh"
live_mode="no"
if [[ $# -eq 1 && "$1" == "--live" ]]; then
  live_mode="yes"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_postgres_debugger_fixture_contract.sh [--live]" >&2
  exit 2
fi

for required_file in \
  "${containerfile}" \
  "${seed_sql}" \
  "${proof_sql}" \
  "${fixture_module}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing PostgreSQL debugger fixture file: ${required_file}" >&2
    exit 1
  }
done

rg -Fq \
  'docker.io/library/postgres:17.4-bookworm@sha256:304ab813518754228f9f792f79d6da36359b82d8ecf418096c636725f8c930ad' \
  "${containerfile}" || {
    echo "The debugger fixture must pin the immutable PostgreSQL 17.4 Bookworm manifest." >&2
    exit 1
  }
rg -Fq 'postgresql-17-pldebugger=1:1.10-1.pgdg12+1' "${containerfile}" || {
  echo "The debugger fixture must pin its PL/pgSQL debugger package." >&2
  exit 1
}
rg -Fq 'CREATE EXTENSION IF NOT EXISTS pldbgapi' "${seed_sql}" || {
  echo "The debugger database must install pldbgapi." >&2
  exit 1
}
rg -Fq 'LANGUAGE plpgsql' "${seed_sql}" || {
  echo "The debugger proof routine must use PL/pgSQL." >&2
  exit 1
}
rg -Fq 'ALTER FUNCTION debugger_proof.calculate_total(integer, integer) OWNER TO dbcode_debugger' \
  "${seed_sql}" || {
    echo "The debugger role must own the proof routine." >&2
    exit 1
  }
rg -Fq 'debugger_proof.calculate_total(5, 3)' "${proof_sql}" || {
  echo "The debugger proof SQL must expose the deterministic result check." >&2
  exit 1
}
rg -Fq '[[ "${extension_version}" == "1.1" ]]' "${fixture_module}" || {
  echo "The live fixture must require the expected pldbgapi extension version." >&2
  exit 1
}

for required_contract in \
  'postgres_debugger_fixture_prepare' \
  'shared_preload_libraries=plugin_debugger' \
  'POSTGRES_HOST_AUTH_METHOD=trust' \
  'HostConfig.PortBindings["5432/tcp"]' \
  '127.0.0.1:${postgres_debugger_port}:5432' \
  'dbcode-wrapper-proof-postgres-debugger' \
  'postgres_debugger_fixture_normalized_image_id' \
  'server_enforced_loopback: true' \
  'expected_result: ($expected_result | tonumber)'; do
  rg -Fq "${required_contract}" "${fixture_module}" || {
    echo "The debugger fixture module is missing: ${required_contract}" >&2
    exit 1
  }
done

if rg -n -i 'password|secret|token|private[_ -]?key' \
  "${fixture_root}" \
  "${fixture_module}"; then
  echo "The local debugger fixture must not store authentication secrets." >&2
  exit 1
fi

rg -Fq 'postgres_container="dbcode-wrapper-proof-postgres"' "${proof_harness}" || {
  echo "The read-only PostgreSQL proof container changed unexpectedly." >&2
  exit 1
}
rg -Fq 'postgres_port="55433"' "${proof_harness}" || {
  echo "The read-only PostgreSQL proof port changed unexpectedly." >&2
  exit 1
}
rg -Fq 'postgres_debugger_fixture_prepare "${workspace_root}"' "${proof_harness}" || {
  echo "The release proof must prepare the separate debugger fixture." >&2
  exit 1
}
rg -Fq 'prepare-debugger)' "${proof_harness}" || {
  echo "The fixture needs a narrow preparation command for SQL-level verification." >&2
  exit 1
}
rg -Fq 'postgresql_debugger' "${proof_harness}" || {
  echo "The release proof must record sanitized debugger fixture evidence." >&2
  exit 1
}
rg -Fq '"debugger"' "${REPO_ROOT}/script/lib/proof_state.sh" || {
  echo "The release proof finalizer must require the debugger observation." >&2
  exit 1
}

if [[ "${live_mode}" == "yes" ]]; then
  live_result="$("${proof_harness}" prepare-debugger)"
  jq -e '
    .fixture.server_enforced_loopback == true
    and .fixture.shared_preload_libraries == "plugin_debugger"
    and .fixture.extension == {name: "pldbgapi", version: "1.1"}
    and .fixture.routine.owner_is_superuser == false
    and .fixture.routine.expected_result == 22
    and (.proof_sql | endswith("/postgres-debugger-proof.sql"))
  ' <<<"${live_result}" >/dev/null || {
    echo "The live debugger fixture did not satisfy its public command contract." >&2
    exit 1
  }
fi

echo "PostgreSQL stored-routine debugger fixture contract checks passed."
