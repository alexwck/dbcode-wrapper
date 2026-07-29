#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

jq -e '
  .product.app_name == "DBCode Wrapper" and
  .product.application_name == "dbcode-wrapper" and
  .product.bundle_identifier == "io.alexabelle.dbcodewrapper" and
  .product.url_scheme == "dbcode-wrapper" and
  .product.data_folder_name == ".dbcode-wrapper" and
  .product.user_data_folder_name == "DBCode Wrapper" and
  .product.extensions_folder_name == "extensions" and
  .product.shared_data_folder_name == ".dbcode-wrapper-shared" and
  .product.backup_folder_name == "DBCode Wrapper Profile Backups" and
  .product.storage_namespace == "dbcode-wrapper" and
  .product.query_folder_name == "queries" and
  .product.signing == {
    mode: "local-certificate",
    identity_common_name: "DBCode Wrapper Local Signing",
    scope: "current-user-private-use"
  } and
  (.product | has("diagnostic") | not)
' <<<"${RELEASE_PROFILE_SPEC}" >/dev/null || {
  echo "The release lock must describe one DBCode Wrapper application." >&2
  exit 1
}

identity_overlay="${REPO_ROOT}/host/patches/vscodium/0001-dbcode-wrapper-identity.patch"
for required_placeholder in \
  '${DBCODE_WRAPPER_APP_NAME}' \
  '${DBCODE_WRAPPER_APPLICATION_NAME}' \
  '${DBCODE_WRAPPER_BUNDLE_IDENTIFIER}' \
  '${DBCODE_WRAPPER_DATA_FOLDER_NAME}' \
  '${DBCODE_WRAPPER_SHARED_DATA_FOLDER_NAME}' \
  '${DBCODE_WRAPPER_STORAGE_NAMESPACE}' \
  '${DBCODE_WRAPPER_QUERY_FOLDER_NAME}' \
  '${DBCODE_WRAPPER_URL_SCHEME}' \
  '${DBCODE_WRAPPER_SERVER_APPLICATION_NAME}' \
  '${DBCODE_WRAPPER_SERVER_DATA_FOLDER_NAME}' \
  '${DBCODE_WRAPPER_TUNNEL_APPLICATION_NAME}' \
  '${DBCODE_WRAPPER_NARROW_BREAKPOINT}' \
  '${DBCODE_WRAPPER_DARWIN_PROFILE_UUID}' \
  '${DBCODE_WRAPPER_DARWIN_PROFILE_PAYLOAD_UUID}'; do
  rg -Fq "${required_placeholder}" "${identity_overlay}" || {
    echo "The host identity overlay must read ${required_placeholder} from the release lock export." >&2
    exit 1
  }
done

if rg -Fq 'setpath "product" "nameShort" "DBCode Wrapper"' "${identity_overlay}"; then
  echo "The host identity overlay must not duplicate the release-lock identity." >&2
  exit 1
fi

for required_export in \
  'DBCODE_WRAPPER_APP_NAME="${APP_NAME}"' \
  'DBCODE_WRAPPER_APPLICATION_NAME="${APPLICATION_NAME}"' \
  'DBCODE_WRAPPER_BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER}"' \
  'DBCODE_WRAPPER_DATA_FOLDER_NAME="${DATA_FOLDER_NAME}"' \
  'DBCODE_WRAPPER_SHARED_DATA_FOLDER_NAME="${SHARED_DATA_FOLDER_NAME}"' \
  'DBCODE_WRAPPER_STORAGE_NAMESPACE="${STORAGE_NAMESPACE}"' \
  'DBCODE_WRAPPER_QUERY_FOLDER_NAME="${QUERY_FOLDER_NAME}"' \
  'DBCODE_WRAPPER_NARROW_BREAKPOINT="${FOCUSED_SHELL_NARROW_BREAKPOINT}"'; do
  rg -Fq "${required_export}" "${REPO_ROOT}/script/compile_host.sh" || {
    echo "Host compilation must export release-lock binding ${required_export}." >&2
    exit 1
  }
done

for required_static_identity_check in \
  "dbcodeWrapperStorageNamespace' \"\${product_json}\")\" == \"\${STORAGE_NAMESPACE}\"" \
  "dbcodeWrapperQueryFolderName' \"\${product_json}\")\" == \"\${QUERY_FOLDER_NAME}\""; do
  rg -Fq "${required_static_identity_check}" "${REPO_ROOT}/script/smoke_host.sh" || {
    echo "Static smoke must verify generated host identity: ${required_static_identity_check}" >&2
    exit 1
  }
done

rg -Fq -- '--profile qa' "${REPO_ROOT}/script/test_focused_shell_rendered.sh" || {
  echo "Rendered shell tests must install DBCode into an isolated QA profile." >&2
  exit 1
}

if rg -Fq 'os.homedir()' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs"; then
  echo "Rendered shell tests must not read extensions from the real user profile." >&2
  exit 1
fi

[[ ! -e "${REPO_ROOT}/script/build_diagnostic_host.sh" ]] || {
  echo "The separate full-workbench diagnostic application must not be built." >&2
  exit 1
}

[[ ! -e "${REPO_ROOT}/host/profile/diagnostic-settings.json" ]] || {
  echo "The removed diagnostic application must not retain a managed profile." >&2
  exit 1
}

for runtime_file in \
  "${REPO_ROOT}/script/build_host.sh" \
  "${REPO_ROOT}/script/assemble_host.sh" \
  "${REPO_ROOT}/script/generate_manifest.sh" \
  "${REPO_ROOT}/script/lib/host_config.sh" \
  "${REPO_ROOT}/script/prepare_dbcode.sh" \
  "${REPO_ROOT}/script/run_host.sh" \
  "${REPO_ROOT}/script/smoke_host.sh"; do
  if rg -q 'DIAGNOSTIC_|development_diagnostic|--diagnostic' "${runtime_file}"; then
    echo "The production workflow still contains diagnostic-app wiring: ${runtime_file}" >&2
    exit 1
  fi
done

rg -Fq -- '--use-mock-keychain' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "Rendered shell tests must not use the real macOS Keychain." >&2
  exit 1
}

rg -Fq 'env -u NODE_OPTIONS' "${REPO_ROOT}/script/generate_manifest.sh" || {
  echo "Manifest generation must isolate the signed Electron runtime from build-only Node options." >&2
  exit 1
}

if [[ -d "${APP_BUNDLE}" ]]; then
  package_json="${APP_BUNDLE}/Contents/Resources/app/package.json"
  app_name="$(jq -er '.productName // .name' "${package_json}")"
  [[ "${app_name}" == "DBCode Wrapper" ]] || {
    echo "The packaged Electron name would address an unexpected Safe Storage key: ${app_name}" >&2
    exit 1
}

rg -Fq 'cryptographic_update_identity_stable' "${REPO_ROOT}/script/generate_manifest.sh" || {
  echo "The build manifest must distinguish cryptographic signing continuity." >&2
  exit 1
}
rg -Fq 'safe_storage_access_stable_across_rebuilds' "${REPO_ROOT}/script/generate_manifest.sh" || {
  echo "The build manifest must state whether rebuilt hosts keep Safe Storage access." >&2
  exit 1
}
rg -Fq 'signing_continuity_evidence="pending-rebuilt-release-comparison"' "${REPO_ROOT}/script/generate_manifest.sh" || {
  echo "A new certificate-signed manifest must wait for a rebuilt-artifact comparison." >&2
  exit 1
}
rg -Fq 'cryptographic_update_identity_stable="null"' "${REPO_ROOT}/script/generate_manifest.sh" || {
  echo "A certificate-signed build must not claim signing continuity without comparing releases." >&2
  exit 1
}
if rg -Fq 'DBCODE_WRAPPER_SIGNING_CONTINUITY_EVIDENCE' "${REPO_ROOT}/script/generate_manifest.sh"; then
  echo "Manifest generation must not accept a retired manual signing receipt." >&2
  exit 1
fi
if rg -Fq 'verified-distinct-rebuilt-artifacts' "${REPO_ROOT}/script/generate_manifest.sh"; then
  echo "Manifest generation must not retain the retired manual signing branch." >&2
  exit 1
fi
fi

echo "Single-app identity and Keychain-isolated test contracts passed."
