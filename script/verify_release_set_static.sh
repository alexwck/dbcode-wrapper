#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"
source "${REPO_ROOT}/script/lib/release_identity.sh"

usage() {
  echo "Usage: ./script/verify_release_set_static.sh --host-set FILE --dbcode-set FILE --output FILE" >&2
  exit 2
}

host_set=""
dbcode_set=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-set) [[ $# -ge 2 ]] || usage; host_set="$2"; shift ;;
    --dbcode-set) [[ $# -ge 2 ]] || usage; dbcode_set="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "${host_set}" && -n "${dbcode_set}" && -n "${output_file}" ]] || usage
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked static receipt: ${output_file}" >&2
  exit 1
}

for required_tool in codesign find jq lipo plutil shasum stat; do
  require_command "${required_tool}"
done

extension_inventory() {
  local extensions_root="$1"
  {
    while IFS= read -r extension_manifest; do
      jq -r '.publisher + "." + .name + "@" + .version' "${extension_manifest}"
    done < <(find "${extensions_root}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
  } | LC_ALL=C sort
}

expected_extension_inventory() {
  local release_lock="$1"
  jq -r '
    ([.extension.dbcode] + (.extension.python_notebooks.packages // []))[]
    | .id + "@" + .version
  ' "${release_lock}" | LC_ALL=C sort
}

extract_entitlements_json() {
  local signed_path="$1"
  local output_plist="$2"
  codesign -d --entitlements :- "${signed_path}" > "${output_plist}" 2>/dev/null
  plutil -convert json -o - "${output_plist}" | jq -S -c .
}

inputs_ready="false"
host_app=""
host_manifest=""
host_lock=""
dbcode_lock=""
dbcode_extensions=""
if approved_release_set_validate "${host_set}" >/dev/null && \
  approved_release_set_validate "${dbcode_set}" >/dev/null && \
  host_app="$(approved_release_set_member "${host_set}" app)" && \
  host_manifest="$(approved_release_set_member "${host_set}" build_manifest)" && \
  host_lock="$(approved_release_set_member "${host_set}" release_lock)" && \
  dbcode_lock="$(approved_release_set_member "${dbcode_set}" release_lock)" && \
  dbcode_extensions="$(approved_release_set_member "${dbcode_set}" extensions)"; then
  inputs_ready="true"
fi

output_parent="$(cd "$(dirname "${output_file}")" && pwd -P)"
check_root="$(mktemp -d "${output_parent}/.static-release-check.XXXXXX")"
cleanup_check_root() {
  [[ -n "${check_root:-}" ]] || return 0
  case "${check_root}" in
    "${output_parent}/.static-release-check."*) rm -rf "${check_root}" ;;
    *) echo "Refusing to remove unexpected static-check path: ${check_root}" >&2; return 1 ;;
  esac
  check_root=""
}
trap cleanup_check_root EXIT INT TERM
failures_file="${check_root}/failures.txt"
: > "${failures_file}"

record_failure() {
  printf '%s\n' "$1" >> "${failures_file}"
}

check_source_and_artifact_identity() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local manifest_schema actual_manifest_sha actual_lock_sha actual_app_sha
  local manifest_release_id descriptor_release_id manifest_source_id descriptor_source_id
  manifest_schema="$(jq -er '.schema_version' "${host_manifest}")"
  actual_manifest_sha="$(shasum -a 256 "${host_manifest}" | awk '{print $1}')"
  actual_lock_sha="$(shasum -a 256 "${host_lock}" | awk '{print $1}')"
  actual_app_sha="$(artifact_digest "${host_app}")"
  descriptor_release_id="$(jq -er '.release.release_set_id' "${host_set}")"
  descriptor_source_id="$(jq -er '.release.source_set_id' "${host_set}")"
  manifest_release_id="$(jq -r '.release.release_set_id // empty' "${host_manifest}")"
  manifest_source_id="$(jq -r '.release.source_set_id // empty' "${host_manifest}")"

  [[ "${actual_manifest_sha}" == "$(jq -er '.host.build_manifest_sha256' "${host_set}")" ]] || return 1
  [[ "${actual_app_sha}" == "$(jq -er '.host.app_sha256' "${host_set}")" ]] || return 1
  [[ "${actual_app_sha}" == "$(jq -er '.artifact.sha256' "${host_manifest}")" ]] || return 1
  [[ "$(jq -er '.runtime.code_oss_version' "${host_lock}")" == "$(jq -er '.host.code_oss_version' "${host_set}")" ]] || return 1
  [[ "$(jq -er '.target.platform' "${host_lock}")" == "$(jq -er '.target.platform' "${host_set}")" ]] || return 1
  [[ "$(jq -er '.target.architecture' "${host_lock}")" == "$(jq -er '.target.architecture' "${host_set}")" ]] || return 1
  [[ -z "$(jq -r '.source.release_lock_sha256 // empty' "${host_manifest}")" || \
    "$(jq -er '.source.release_lock_sha256' "${host_manifest}")" == "${actual_lock_sha}" ]] || return 1
  if [[ "${manifest_schema}" -ge 5 ]]; then
    [[ "${manifest_release_id}" == "${descriptor_release_id}" ]] || return 1
    [[ "${manifest_source_id}" == "${descriptor_source_id}" ]] || return 1
  else
    [[ "$(jq -er '.role' "${host_set}")" == "current" ]] || return 1
  fi
  [[ "$(jq -er '.artifact.app_name' "${host_manifest}")" == "${APP_NAME}" ]] || return 1
  [[ "$(plutil -extract CFBundleName raw "${host_app}/Contents/Info.plist")" == "${APP_NAME}" ]] || return 1
  [[ "$(plutil -extract CFBundleIdentifier raw "${host_app}/Contents/Info.plist")" == "${BUNDLE_IDENTIFIER}" ]] || return 1
}

check_hashes_and_signatures() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local actual_extensions_sha actual_inventory expected_inventory
  codesign --verify --deep --strict "${host_app}" >/dev/null 2>&1 || return 1
  [[ "$(codesign -d -r- "${host_app}" 2>&1 | sed -n '/^designated => /p')" == \
    "$(jq -er '.artifact.signature_requirement' "${host_manifest}")" ]] || return 1
  [[ "$(jq -er '.extension.dbcode.sha256' "${dbcode_lock}")" == \
    "$(jq -er '.dbcode.vsix_sha256' "${dbcode_set}")" ]] || return 1
  [[ "$(jq -er '.extension.dbcode.signature_archive_sha256' "${dbcode_lock}")" == \
    "$(jq -er '.dbcode.signature_archive_sha256' "${dbcode_set}")" ]] || return 1
  actual_extensions_sha="$(directory_content_digest "${dbcode_extensions}")"
  [[ "${actual_extensions_sha}" == "$(jq -er '.profile.extensions_sha256' "${dbcode_set}")" ]] || return 1
  actual_inventory="$(extension_inventory "${dbcode_extensions}")"
  expected_inventory="$(expected_extension_inventory "${dbcode_lock}")"
  [[ "${actual_inventory}" == "${expected_inventory}" ]] || return 1
  [[ "$(jq -c '.profile.installed_extensions | sort' "${dbcode_set}")" == \
    "$(jq -R -s -c 'split("\n") | map(select(length > 0)) | sort' <<<"${actual_inventory}")" ]] || return 1
}

check_architecture_and_minimum_macos() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local info_plist executable_name executable_path architecture expected_arch minimum_macos current_macos
  info_plist="${host_app}/Contents/Info.plist"
  executable_name="$(plutil -extract CFBundleExecutable raw "${info_plist}")" || return 1
  executable_path="${host_app}/Contents/MacOS/${executable_name}"
  [[ -x "${executable_path}" && ! -L "${executable_path}" ]] || return 1
  architecture="$(lipo -archs "${executable_path}")" || return 1
  expected_arch="$(jq -er '.target.architecture' "${host_set}")"
  [[ "${architecture}" == "${expected_arch}" ]] || return 1
  minimum_macos="$(plutil -extract LSMinimumSystemVersion raw "${info_plist}")" || return 1
  current_macos="$(sw_vers -productVersion)"
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/check_vscode_engine.cjs" \
    "${current_macos}" ">=${minimum_macos}" >/dev/null 2>&1
}

check_dbcode_engine_compatible() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local host_version expected_inventory extension_manifest extension_id extension_version extension_engine
  host_version="$(jq -er '.host.code_oss_version' "${host_set}")"
  expected_inventory="$(expected_extension_inventory "${dbcode_lock}")"
  while IFS= read -r extension_manifest; do
    extension_id="$(jq -er '.publisher + "." + .name' "${extension_manifest}")" || return 1
    extension_version="$(jq -er '.version' "${extension_manifest}")" || return 1
    extension_engine="$(jq -er '.engines.vscode' "${extension_manifest}")" || return 1
    grep -Fxq "${extension_id}@${extension_version}" <<<"${expected_inventory}" || return 1
    "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/check_vscode_engine.cjs" \
      "${host_version}" "${extension_engine}" >/dev/null 2>&1 || return 1
  done < <(find "${dbcode_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
}

check_unchanged_extension_packages() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local dbcode_role release_id history_file package_root approved_record
  dbcode_role="$(jq -er '.role' "${dbcode_set}")"
  if release_specification_same_dbcode_payload "${LOCK_FILE}" "${dbcode_lock}"; then
    while IFS=$'\t' read -r extension_id extension_version <&3; do
      package_root="${CACHE_ROOT}/runtime-extensions/${extension_id}/${extension_version}"
      "${REPO_ROOT}/script/verify_openvsx_package.sh" \
        "${extension_id}" "${package_root}" >/dev/null || return 1
      "${REPO_ROOT}/script/verify_installed_extension_payload.sh" \
        "${package_root}/package.vsix" \
        "${dbcode_extensions}" \
        "${extension_id}" \
        "${extension_version}" >/dev/null || return 1
    done 3< <(jq -r '.[] | [.id, .version] | @tsv' <<<"${RUNTIME_EXTENSION_PACKAGES}")
    return 0
  fi

  [[ "${dbcode_role}" == "current" ]] || return 1
  release_id="$(jq -er '.release.release_set_id' "${dbcode_set}")"
  history_file="${REPO_ROOT}/host/approved-release-history.json"
  approved_record="$(approved_release_history_record "${history_file}" "${release_id}")" || return 1
  jq -e \
    --arg dbcode_id "$(jq -er '.dbcode.id' "${dbcode_set}")" \
    --arg dbcode_version "$(jq -er '.dbcode.version' "${dbcode_set}")" \
    --arg dbcode_sha "$(jq -er '.dbcode.vsix_sha256' "${dbcode_set}")" \
    --arg signature_sha "$(jq -er '.dbcode.signature_archive_sha256' "${dbcode_set}")" '
      .compatibility_status == "approved"
      and .dbcode.id == $dbcode_id
      and .dbcode.version == $dbcode_version
      and .dbcode.vsix_sha256 == $dbcode_sha
      and .dbcode.signature_archive_sha256 == $signature_sha
    ' <<<"${approved_record}" >/dev/null || return 1
  "${REPO_ROOT}/script/verify_release_rollback.sh" "${release_id}" >/dev/null
}

check_connection_capability_contract() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local host_version dbcode_id dbcode_version extension_manifest="" candidate_manifest
  local dbcode_role host_role release_id approved_record
  host_version="$(jq -er '.host.code_oss_version' "${host_set}")"
  dbcode_id="$(jq -er '.dbcode.id' "${dbcode_set}")"
  dbcode_version="$(jq -er '.dbcode.version' "${dbcode_set}")"

  if release_specification_same_dbcode_payload "${LOCK_FILE}" "${dbcode_lock}" && \
    [[ "${host_version}" == "$(jq -er '.host.code_oss.version' "${REPO_ROOT}/host/dbcode-feature-policy.json")" ]]; then
    while IFS= read -r candidate_manifest; do
      if jq -e --arg id "${dbcode_id}" --arg version "${dbcode_version}" \
        '(.publisher + "." + .name) == $id and .version == $version' \
        "${candidate_manifest}" >/dev/null 2>&1; then
        extension_manifest="${candidate_manifest}"
        break
      fi
    done < <(find "${dbcode_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
    [[ -n "${extension_manifest}" ]] || return 1
    "${REPO_ROOT}/script/test_dbcode_feature_contract.sh" --manifest "${extension_manifest}" >/dev/null
    return
  fi

  dbcode_role="$(jq -er '.role' "${dbcode_set}")"
  host_role="$(jq -er '.role' "${host_set}")"
  [[ "${dbcode_role}" == "current" && "${host_role}" == "current" ]] || return 1
  release_id="$(jq -er '.release.release_set_id' "${dbcode_set}")"
  [[ "${release_id}" == "$(jq -er '.release.release_set_id' "${host_set}")" ]] || return 1
  approved_record="$(approved_release_history_record "${REPO_ROOT}/host/approved-release-history.json" "${release_id}")" || return 1
  jq -e '.compatibility_status == "approved"' <<<"${approved_record}" >/dev/null
}

check_extension_allowlist_exact() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local host_role manifest_schema actual_allowlist expected_allowlist release_id
  host_role="$(jq -er '.role' "${host_set}")"
  manifest_schema="$(jq -er '.schema_version' "${host_manifest}")"
  if [[ "${manifest_schema}" -ge 5 ]] && \
    release_specification_same_host_build_contract "${LOCK_FILE}" "${host_lock}"; then
    expected_allowlist="$(jq -c '
      ([.build.built_in_extensions.allowlist[].name] +
       [.build.built_in_extensions.first_party[].name]) | sort
    ' "${REPO_ROOT}/host/slimming-policy.json")"
    actual_allowlist="$(find "${host_app}/Contents/Resources/app/extensions" \
      -mindepth 2 -maxdepth 2 -name package.json -type f -print |
      sed 's#/package.json$##; s#.*/extensions/##' |
      LC_ALL=C sort |
      jq -R -s -c 'split("\n") | map(select(length > 0))')"
    [[ "${actual_allowlist}" == "${expected_allowlist}" ]] || return 1
    [[ "$(find "${host_app}" -type f -name '*.map' -print | wc -l | tr -d ' ')" == "0" ]] || return 1
    [[ "$(find "${host_app}" -path '*/extensions/dbcode.dbcode-*' -print -quit)" == "" ]] || return 1
    return 0
  fi

  [[ "${host_role}" == "current" ]] || return 1
  release_id="$(jq -er '.release.release_set_id' "${host_set}")"
  "${REPO_ROOT}/script/verify_release_rollback.sh" "${release_id}" >/dev/null
}

check_nested_signature_and_entitlements() {
  [[ "${inputs_ready}" == "true" ]] || return 1
  local actual_entitlements expected_entitlements nested_path nested_name entitlement_role
  local entitlement_plist="${check_root}/entitlements.plist"
  codesign --verify --deep --strict "${host_app}" >/dev/null 2>&1 || return 1
  actual_entitlements="$(extract_entitlements_json "${host_app}" "${entitlement_plist}")" || return 1
  expected_entitlements="$(jq -S -c '.artifact.entitlements.app' "${host_manifest}")" || return 1
  [[ "${actual_entitlements}" == "${expected_entitlements}" ]] || return 1

  while IFS= read -r nested_path; do
    codesign --verify --strict "${nested_path}" >/dev/null 2>&1 || return 1
  done < <(find "${host_app}/Contents" -mindepth 2 \( -name '*.app' -o -name '*.framework' \) -print)

  while IFS= read -r nested_path; do
    nested_name="$(basename "${nested_path}")"
    case "${nested_name}" in
      *Plugin*) entitlement_role="plugin" ;;
      *) entitlement_role="helper" ;;
    esac
    actual_entitlements="$(extract_entitlements_json "${nested_path}" "${entitlement_plist}")" || return 1
    expected_entitlements="$(jq -S -c --arg role "${entitlement_role}" '.artifact.entitlements[$role]' "${host_manifest}")" || return 1
    [[ "${actual_entitlements}" == "${expected_entitlements}" ]] || return 1
  done < <(find "${host_app}/Contents" -mindepth 2 -name '*.app' -print)
}

source_and_artifact_identity="false"
hashes_and_signatures="false"
architecture_and_minimum_macos="false"
dbcode_engine_compatible="false"
unchanged_extension_packages="false"
connection_capability_contract="false"
extension_allowlist_exact="false"
nested_signature_and_entitlements="false"

if check_source_and_artifact_identity >"${check_root}/identity.log" 2>&1; then
  source_and_artifact_identity="true"
else
  record_failure "source-and-artifact-identity"
fi
if check_hashes_and_signatures >"${check_root}/hashes.log" 2>&1; then
  hashes_and_signatures="true"
else
  record_failure "hashes-and-signatures"
fi
if check_architecture_and_minimum_macos >"${check_root}/architecture.log" 2>&1; then
  architecture_and_minimum_macos="true"
else
  record_failure "architecture-and-minimum-macos"
fi
if check_dbcode_engine_compatible >"${check_root}/engine.log" 2>&1; then
  dbcode_engine_compatible="true"
else
  record_failure "dbcode-engine-compatible"
fi
if check_unchanged_extension_packages >"${check_root}/packages.log" 2>&1; then
  unchanged_extension_packages="true"
else
  record_failure "unchanged-extension-packages"
fi
if check_connection_capability_contract >"${check_root}/connection-capabilities.log" 2>&1; then
  connection_capability_contract="true"
else
  record_failure "connection-capability-contract"
fi
if check_extension_allowlist_exact >"${check_root}/allowlist.log" 2>&1; then
  extension_allowlist_exact="true"
else
  record_failure "extension-allowlist-exact"
fi
if check_nested_signature_and_entitlements >"${check_root}/nested-signatures.log" 2>&1; then
  nested_signature_and_entitlements="true"
else
  record_failure "nested-signature-and-entitlements"
fi

status="failed"
if [[ "${source_and_artifact_identity}" == "true" && \
  "${hashes_and_signatures}" == "true" && \
  "${architecture_and_minimum_macos}" == "true" && \
  "${dbcode_engine_compatible}" == "true" && \
  "${unchanged_extension_packages}" == "true" && \
  "${connection_capability_contract}" == "true" && \
  "${extension_allowlist_exact}" == "true" && \
  "${nested_signature_and_entitlements}" == "true" ]]; then
  status="passed"
fi

receipt_temp="${check_root}/static-receipt.json"
jq -n \
  --arg checked_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg status "${status}" \
  --argjson source_and_artifact_identity "${source_and_artifact_identity}" \
  --argjson hashes_and_signatures "${hashes_and_signatures}" \
  --argjson architecture_and_minimum_macos "${architecture_and_minimum_macos}" \
  --argjson dbcode_engine_compatible "${dbcode_engine_compatible}" \
  --argjson unchanged_extension_packages "${unchanged_extension_packages}" \
  --argjson connection_capability_contract "${connection_capability_contract}" \
  --argjson extension_allowlist_exact "${extension_allowlist_exact}" \
  --argjson nested_signature_and_entitlements "${nested_signature_and_entitlements}" \
  --arg failures "$(cat "${failures_file}")" '
    {
      schema_version: 1,
      checked_at_utc: $checked_at_utc,
      status: $status,
      source_and_artifact_identity: $source_and_artifact_identity,
      hashes_and_signatures: $hashes_and_signatures,
      architecture_and_minimum_macos: $architecture_and_minimum_macos,
      dbcode_engine_compatible: $dbcode_engine_compatible,
      unchanged_extension_packages: $unchanged_extension_packages,
      connection_capability_contract: $connection_capability_contract,
      extension_allowlist_exact: $extension_allowlist_exact,
      nested_signature_and_entitlements: $nested_signature_and_entitlements,
      failures: ($failures | split("\n") | map(select(length > 0)))
    }
  ' > "${receipt_temp}"
mv "${receipt_temp}" "${output_file}"
chmod 600 "${output_file}"

if [[ "${status}" != "passed" ]]; then
  echo "Static release-set checks failed: ${output_file}" >&2
  exit 1
fi
echo "Static release-set checks passed: ${output_file}"
