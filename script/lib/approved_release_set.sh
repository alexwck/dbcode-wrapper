#!/usr/bin/env bash

set -euo pipefail

approved_release_set_cli() {
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/approved_release_set.cjs" "$@"
}

approved_release_record_validate() {
  approved_release_set_cli validate-approved "$1"
}

approved_release_history_validate() {
  approved_release_set_cli validate-history "$1"
}

approved_release_set_validate_recorded_approval() {
  approved_release_set_cli validate-recorded-approval \
    "$1" "$2" "$3" "$4" "$5" "$6"
}

approved_release_history_record() {
  approved_release_set_cli history-record "$1" "$2"
}

approved_release_history_record_approval() {
  approved_release_set_cli record-approved-history "$1" "$2" "$3" "$4"
}

approved_release_set_prompt_free_verification_checks() {
  approved_release_set_cli prompt-free-verification-checks
}

approved_release_set_write_prompt_free_approval() {
  approved_release_set_cli write-prompt-free-approval "$@"
}
