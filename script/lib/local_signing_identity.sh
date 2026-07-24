#!/usr/bin/env bash

if [[ "${DBCODE_WRAPPER_LOCAL_SIGNING_LIBRARY_LOADED:-}" == "yes" ]]; then
  return 0 2>/dev/null || exit 0
fi
DBCODE_WRAPPER_LOCAL_SIGNING_LIBRARY_LOADED="yes"

if [[ -z "${SIGNING_MODE:-}" || -z "${SIGNING_SCOPE:-}" || -z "${SIGNING_IDENTITY_COMMON_NAME:-}" ]]; then
  echo "Load host_config.sh before local_signing_identity.sh." >&2
  return 1 2>/dev/null || exit 1
fi

local_signing_user_home="$(current_user_home)"
LOCAL_SIGNING_ROOT="${DBCODE_WRAPPER_SIGNING_ROOT:-${local_signing_user_home}/Library/Application Support/DBCode Wrapper/Signing}"
LOCAL_SIGNING_METADATA_FILE="${LOCAL_SIGNING_ROOT}/identity.json"

local_signing_file_mode() {
  stat -f '%Lp' "$1"
}

local_signing_assert_owner_only_file() {
  local path="$1"
  local expected_mode="$2"
  [[ -f "${path}" && ! -L "${path}" ]] || {
    echo "Missing or unsafe local-signing file: ${path}" >&2
    return 1
  }
  [[ "$(stat -f '%u' "${path}")" == "$(id -u)" ]] || {
    echo "Local-signing file is not owned by the current user: ${path}" >&2
    return 1
  }
  [[ "$(local_signing_file_mode "${path}")" == "${expected_mode}" ]] || {
    echo "Local-signing file must have mode ${expected_mode}: ${path}" >&2
    return 1
  }
}

load_local_signing_metadata() {
  [[ "${SIGNING_MODE}" == "local-certificate" ]] || {
    echo "Unsupported signing mode: ${SIGNING_MODE}" >&2
    return 1
  }
  [[ -d "${LOCAL_SIGNING_ROOT}" && ! -L "${LOCAL_SIGNING_ROOT}" ]] || {
    echo "Local signing is not set up. Run ./script/setup_local_signing_identity.sh" >&2
    return 1
  }
  [[ "$(stat -f '%u' "${LOCAL_SIGNING_ROOT}")" == "$(id -u)" ]] || {
    echo "The local-signing directory is not owned by the current user." >&2
    return 1
  }
  [[ "$(local_signing_file_mode "${LOCAL_SIGNING_ROOT}")" == "700" ]] || {
    echo "The local-signing directory must have mode 700." >&2
    return 1
  }
  local_signing_assert_owner_only_file "${LOCAL_SIGNING_METADATA_FILE}" 600 || return 1

  jq -e \
    --arg mode "${SIGNING_MODE}" \
    --arg scope "${SIGNING_SCOPE}" \
    --arg common_name "${SIGNING_IDENTITY_COMMON_NAME}" '
      .schema_version == 1
      and .mode == $mode
      and .scope == $scope
      and .identity_common_name == $common_name
      and (.keychain | type == "string" and startswith("/"))
      and (.certificate_sha1 | test("^[0-9A-F]{40}$"))
      and (.certificate_sha256 | test("^[0-9a-f]{64}$"))
      and (.certificate_path | test("^[A-Za-z0-9._-]+$"))
    ' "${LOCAL_SIGNING_METADATA_FILE}" >/dev/null || {
    echo "The local-signing metadata is invalid." >&2
    return 1
  }

  LOCAL_SIGNING_KEYCHAIN="$(jq -er '.keychain' "${LOCAL_SIGNING_METADATA_FILE}")"
  LOCAL_SIGNING_CERTIFICATE_SHA1="$(jq -er '.certificate_sha1' "${LOCAL_SIGNING_METADATA_FILE}")"
  LOCAL_SIGNING_CERTIFICATE_SHA256="$(jq -er '.certificate_sha256' "${LOCAL_SIGNING_METADATA_FILE}")"
  LOCAL_SIGNING_CERTIFICATE_FILE="${LOCAL_SIGNING_ROOT}/$(jq -er '.certificate_path' "${LOCAL_SIGNING_METADATA_FILE}")"
  LOCAL_SIGNING_IDENTITY="${LOCAL_SIGNING_CERTIFICATE_SHA1}"

  case "${LOCAL_SIGNING_KEYCHAIN}" in
    "${local_signing_user_home}/Library/Keychains/"*) ;;
    *)
      echo "The signing identity must stay in the current user's Keychains folder." >&2
      return 1
      ;;
  esac
  [[ -f "${LOCAL_SIGNING_KEYCHAIN}" && ! -L "${LOCAL_SIGNING_KEYCHAIN}" ]] || {
    echo "The configured signing Keychain is missing or unsafe." >&2
    return 1
  }
  local_signing_assert_owner_only_file "${LOCAL_SIGNING_CERTIFICATE_FILE}" 600 || return 1
}

local_signing_certificate_hashes() {
  local certificate_file="$1"
  local certificate_der
  certificate_der="$(mktemp "${TMPDIR:-/private/tmp}/dbcode-wrapper-certificate.XXXXXX")"
  cleanup_certificate_der() {
    rm -f "${certificate_der}"
  }
  trap cleanup_certificate_der RETURN
  openssl x509 -in "${certificate_file}" -outform DER -out "${certificate_der}"
  printf '%s\t%s\n' \
    "$(shasum "${certificate_der}" | awk '{print toupper($1)}')" \
    "$(shasum -a 256 "${certificate_der}" | awk '{print $1}')"
  cleanup_certificate_der
  trap - RETURN
}

local_signing_expected_requirement() {
  local signing_identifier="$1"
  [[ "${signing_identifier}" =~ ^[A-Za-z0-9.-]+$ ]] || {
    echo "Invalid signing identifier: ${signing_identifier}" >&2
    return 1
  }
  printf 'designated => certificate root = H"%s" and identifier "%s"\n' \
    "${LOCAL_SIGNING_CERTIFICATE_SHA1,,}" \
    "${signing_identifier}"
}

load_local_signing_identity() {
  local actual_sha1 actual_sha256 valid_identity_line
  require_command jq
  require_command openssl
  require_command security
  require_command shasum
  require_command stat
  load_local_signing_metadata || return 1
  IFS=$'\t' read -r actual_sha1 actual_sha256 < <(local_signing_certificate_hashes "${LOCAL_SIGNING_CERTIFICATE_FILE}")
  [[ "${actual_sha1}" == "${LOCAL_SIGNING_CERTIFICATE_SHA1}" && \
    "${actual_sha256}" == "${LOCAL_SIGNING_CERTIFICATE_SHA256}" ]] || {
    echo "The stored public signing certificate does not match its metadata." >&2
    return 1
  }
  valid_identity_line="$(security find-identity -v -p codesigning "${LOCAL_SIGNING_KEYCHAIN}" | \
    awk -v sha="${LOCAL_SIGNING_CERTIFICATE_SHA1}" -v name="${SIGNING_IDENTITY_COMMON_NAME}" \
      '$2 == sha && index($0, "\"" name "\"") > 0 {print; found++} END {if (found != 1) exit 1}')" || {
    echo "The persistent DBCode Wrapper code-signing identity is not valid." >&2
    echo "Run ./script/setup_local_signing_identity.sh and approve its user-level code-signing trust request." >&2
    return 1
  }
  [[ -n "${valid_identity_line}" ]]
}

verify_local_signed_code() {
  local signed_path="$1"
  local signing_identifier="$2"
  local expected_requirement actual_requirement signature_details
  load_local_signing_identity
  expected_requirement="$(local_signing_expected_requirement "${signing_identifier}")"
  codesign --verify --deep --strict --verbose=2 "${signed_path}"
  codesign --verify --strict --verbose=2 \
    -R="anchor H\"${LOCAL_SIGNING_CERTIFICATE_SHA1}\" and identifier \"${signing_identifier}\"" \
    "${signed_path}"
  actual_requirement="$(codesign -d -r- "${signed_path}" 2>&1 | sed -n '/^designated => /p')"
  [[ "${actual_requirement}" == "${expected_requirement}" ]] || {
    echo "The signed code has an unexpected designated requirement." >&2
    echo "Expected: ${expected_requirement}" >&2
    echo "Actual:   ${actual_requirement}" >&2
    return 1
  }
  signature_details="$(codesign -dvvv "${signed_path}" 2>&1)"
  [[ "${signature_details}" != *'Signature=adhoc'* ]] || {
    echo "The release is still ad-hoc signed." >&2
    return 1
  }
}
