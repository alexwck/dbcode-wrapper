#!/usr/bin/env bash

set -euo pipefail

approved_release_set_cli() {
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/approved_release_set.cjs" "$@"
}

approved_release_set_validate() {
  approved_release_set_cli validate-set "$1"
}

approved_release_set_member() {
  approved_release_set_cli member "$1" "$2"
}

approved_release_record_validate() {
  approved_release_set_cli validate-approved "$1"
}

approved_release_history_validate() {
  approved_release_set_cli validate-history "$1"
}

approved_release_history_record() {
  approved_release_set_cli history-record "$1" "$2"
}

approved_release_set_write_approval() {
  approved_release_set_cli write-approval "$@"
}
