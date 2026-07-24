#!/usr/bin/env bash

set -euo pipefail

layout_file=""
state_file=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout) layout_file="$2"; shift ;;
    --state) state_file="$2"; shift ;;
    --output) output_file="$2"; shift ;;
    *) echo "Unknown fake health-gate option: $1" >&2; exit 2 ;;
  esac
  shift
done

jq -n \
  --arg checked_at_utc "2026-07-21T06:00:00Z" \
  --arg release_set_id "$(jq -r '.active.release_set_id' "${state_file}")" \
  --arg app_sha256 "$(jq -r '.active.app_sha256' "${state_file}")" \
  --arg manifest_sha256 "$(jq -r '.active.build_manifest_sha256' "${state_file}")" \
  --arg extensions_sha256 "$(jq -r '.active.extensions_sha256' "${state_file}")" '
    {
      schema_version: 1,
      checked_at_utc: $checked_at_utc,
      release_set_id: $release_set_id,
      app_sha256: $app_sha256,
      build_manifest_sha256: $manifest_sha256,
      extensions_sha256: $extensions_sha256,
      first_launch_ready: true,
      first_quit_complete: true,
      relaunch_ready: true,
      final_quit_complete: true,
      dbcode_started: true,
      account_restored: true,
      keychain_error_absent: true,
      surprise_update_absent: true,
      status: "passed"
    }
  ' > "${output_file}"
