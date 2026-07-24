#!/usr/bin/env bash

set -euo pipefail

output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-set|--dbcode-set) shift ;;
    --output) output_file="$2"; shift ;;
    *) echo "Unknown fake static-gate option: $1" >&2; exit 2 ;;
  esac
  shift
done

jq -n '
  {
    schema_version: 1,
    status: "passed",
    source_and_artifact_identity: true,
    hashes_and_signatures: true,
    architecture_and_minimum_macos: true,
    dbcode_engine_compatible: true,
    unchanged_extension_packages: true,
    connection_capability_contract: true,
    extension_allowlist_exact: true,
    nested_signature_and_entitlements: true
  }
' > "${output_file}"
