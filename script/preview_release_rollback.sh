#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

release_id="${1:-}"
profile_source="${2:---snapshot-profile}"
[[ -n "${release_id}" && "${release_id}" =~ ^[a-z0-9][a-z0-9._-]+$ ]] || {
  echo "Usage: ./script/preview_release_rollback.sh <release-id> [--snapshot-profile|--clone-current-profile]" >&2
  exit 2
}
case "${profile_source}" in
  --snapshot-profile|--clone-current-profile) ;;
  *) echo "Unknown rollback preview option: ${profile_source}" >&2; exit 2;;
esac

"${REPO_ROOT}/script/verify_release_rollback.sh" "${release_id}"
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  echo "Quit ${APP_NAME} before opening an isolated rollback preview." >&2
  exit 1
fi

snapshot_root="${BUILD_ROOT}/approved-release-backups/${release_id}"
snapshot_app="${snapshot_root}/${APP_NAME}.app"
preview_root="$(mktemp -d /private/tmp/dbcode-rollback-preview.XXXXXX)"
cleanup_preview() {
  case "${preview_root}" in
    /private/tmp/dbcode-rollback-preview.*) rm -rf "${preview_root}" ;;
    *) echo "Refusing to remove unexpected rollback preview path: ${preview_root}" >&2; return 1;;
  esac
}
trap cleanup_preview EXIT INT TERM

if [[ "${profile_source}" == "--clone-current-profile" ]]; then
  user_home_dir="$(current_user_home)"
  current_user_data="${user_home_dir}/Library/Application Support/${APP_NAME}"
  current_shared_data="${user_home_dir}/${SHARED_DATA_FOLDER_NAME}"
  [[ -d "${current_user_data}" ]] || { echo "Current DBCode Wrapper profile is missing." >&2; exit 1; }
  ditto "${current_user_data}" "${preview_root}/user-data"
  if [[ -d "${current_shared_data}" ]]; then
    ditto "${current_shared_data}" "${preview_root}/shared-data"
  else
    mkdir -p "${preview_root}/shared-data"
  fi
else
  ditto "${snapshot_root}/profile/user-data" "${preview_root}/user-data"
  ditto "${snapshot_root}/profile/shared-data" "${preview_root}/shared-data"
fi
ditto "${snapshot_root}/profile/extensions" "${preview_root}/extensions"
chmod -R u+rwX,go-rwx "${preview_root}"

bundle_executable="$(plutil -extract CFBundleExecutable raw "${snapshot_app}/Contents/Info.plist")"
app_executable="${snapshot_app}/Contents/MacOS/${bundle_executable}"
"${app_executable}" \
  --user-data-dir "${preview_root}/user-data" \
  --extensions-dir "${preview_root}/extensions" \
  --shared-data-dir "${preview_root}/shared-data" \
  --disable-telemetry \
  --disable-updates \
  --new-window \
  --skip-release-notes \
  --skip-welcome

echo "Rollback preview completed without replacing the current app or profile."
