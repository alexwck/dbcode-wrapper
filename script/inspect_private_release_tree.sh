#!/usr/bin/env bash

set -euo pipefail

release_root=""
app_name=""
guide_name=""

usage() {
  echo "Usage: ./script/inspect_private_release_tree.sh --root DIR --app-name NAME.app --guide-name NAME.txt" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) [[ $# -ge 2 ]] || usage; release_root="$2"; shift ;;
    --app-name) [[ $# -ge 2 ]] || usage; app_name="$2"; shift ;;
    --guide-name) [[ $# -ge 2 ]] || usage; guide_name="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

[[ -n "${release_root}" && -n "${app_name}" && -n "${guide_name}" ]] || usage
[[ -d "${release_root}" && ! -L "${release_root}" ]] || {
  echo "The Private Personal Release root is missing or unsafe." >&2
  exit 1
}
[[ "${app_name}" =~ ^[A-Za-z0-9._[:space:]-]+\.app$ ]] || {
  echo "The release app name is invalid." >&2
  exit 1
}
[[ "${guide_name}" =~ ^[A-Za-z0-9._[:space:]-]+\.txt$ ]] || {
  echo "The release guide name is invalid." >&2
  exit 1
}

app_path="${release_root}/${app_name}"
guide_path="${release_root}/${guide_name}"
[[ -d "${app_path}" && ! -L "${app_path}" ]] || {
  echo "The release does not contain the expected host application." >&2
  exit 1
}
[[ -f "${guide_path}" && ! -L "${guide_path}" ]] || {
  echo "The release does not contain the expected install guide." >&2
  exit 1
}

expected_entries="$(printf '%s\n' "${app_name}" "${guide_name}" | LC_ALL=C sort)"
actual_entries="$(find "${release_root}" -mindepth 1 -maxdepth 1 -print | sed 's#^.*/##' | LC_ALL=C sort)"
[[ "${actual_entries}" == "${expected_entries}" ]] || {
  echo "The release root must contain only the host app and install guide." >&2
  exit 1
}

release_root_real="$(realpath "${release_root}")"
unsafe_links="$(
  while IFS= read -r link_path; do
    resolved_path="$(realpath "${link_path}" 2>/dev/null || true)"
    case "${resolved_path}" in
      "${release_root_real}"/*) ;;
      *) printf '%s\n' "${link_path#"${release_root}/"}" ;;
    esac
  done < <(find "${app_path}" -type l -print)
)"
[[ -z "${unsafe_links}" ]] || {
  echo "The release contains a broken or escaping symbolic link." >&2
  printf '%s\n' "${unsafe_links}" >&2
  exit 1
}

for required_statement in \
  'for Macs owned by the licence holder' \
  'DBCode is not included' \
  'Verify the published SHA-256' \
  'System Settings > Privacy & Security > Open Anyway' \
  'Do not disable Gatekeeper' \
  'self-signed' \
  'Apple has neither identified nor notarized it' \
  'Rollback'; do
  rg -Fq "${required_statement}" "${guide_path}" || {
    echo "The install guide is missing: ${required_statement}" >&2
    exit 1
  }
done

bundled_dbcode_paths="$(
  find "${app_path}" -mindepth 1 -print |
    while IFS= read -r path; do
      relative_path="${path#"${app_path}/"}"
      case "${relative_path}" in
        extensions/dbcode.dbcode | \
        extensions/dbcode.dbcode-* | \
        */extensions/dbcode.dbcode | \
        */extensions/dbcode.dbcode-*)
          printf '%s\n' "${relative_path}"
          ;;
      esac
    done
)"
while IFS= read -r package_manifest; do
  [[ -n "${package_manifest}" ]] || continue
  if jq -e '.publisher == "dbcode" and .name == "dbcode"' \
    "${package_manifest}" >/dev/null 2>&1; then
    bundled_dbcode_paths+="${bundled_dbcode_paths:+$'\n'}${package_manifest#"${app_path}/"}"
  fi
done < <(find "${app_path}" -type f -name package.json -print)
[[ -z "${bundled_dbcode_paths}" ]] || {
  echo "The release contains an installed DBCode extension package." >&2
  printf '%s\n' "${bundled_dbcode_paths}" >&2
  exit 1
}

private_profile_paths="$(
  find "${app_path}" -mindepth 1 -print |
    while IFS= read -r path; do
      relative_path="${path#"${app_path}/"}"
      case "${relative_path}" in
        .dbcode-wrapper | \
        .dbcode-wrapper/* | \
        */.dbcode-wrapper | \
        */.dbcode-wrapper/* | \
        .dbcode-wrapper-shared | \
        .dbcode-wrapper-shared/* | \
        */.dbcode-wrapper-shared | \
        */.dbcode-wrapper-shared/* | \
        User/globalStorage | \
        User/globalStorage/* | \
        */User/globalStorage | \
        */User/globalStorage/* | \
        User/workspaceStorage | \
        User/workspaceStorage/* | \
        */User/workspaceStorage | \
        */User/workspaceStorage/* | \
        User/History | \
        User/History/* | \
        */User/History | \
        */User/History/* | \
        user-data | \
        user-data/* | \
        */user-data | \
        */user-data/* | \
        CachedExtensionVSIXs | \
        CachedExtensionVSIXs/* | \
        */CachedExtensionVSIXs | \
        */CachedExtensionVSIXs/* | \
        CachedExtensions | \
        CachedExtensions/* | \
        */CachedExtensions | \
        */CachedExtensions/* | \
        */extensions/.obsolete | \
        */extensions/extensions.json | \
        state.vscdb | \
        */state.vscdb | \
        */dbcode.dbcode | \
        */dbcode.dbcode/*)
          printf '%s\n' "${relative_path}"
          ;;
      esac
    done
)"
[[ -z "${private_profile_paths}" ]] || {
  echo "The release contains Standalone DBCode Profile state." >&2
  printf '%s\n' "${private_profile_paths}" >&2
  exit 1
}

private_payload_paths="$(
  find "${app_path}" -type f -print |
    while IFS= read -r path; do
      relative_path="${path#"${app_path}/"}"
      lowercase_path="$(printf '%s' "${relative_path}" | tr '[:upper:]' '[:lower:]')"
      case "${lowercase_path}" in
        *.vsix | \
        *.dmg | \
        *.db | \
        *.db3 | \
        *.sqlite | \
        *.sqlite3 | \
        *.duckdb | \
        *.parquet | \
        *.db-journal | \
        *.db-shm | \
        *.db-wal | \
        *.sqlite-journal | \
        *.sqlite-shm | \
        *.sqlite-wal | \
        *.duckdb.wal | \
        *.p12 | \
        *.pfx | \
        *.key | \
        *.pem | \
        *.cer | \
        *.crt | \
        *.mobileprovision | \
        *.keychain | \
        *.keychain-db | \
        *.env | \
        *.env.* | \
        *.netrc | \
        *.npmrc | \
        *.pgpass | \
        *.my.cnf | \
        */credentials | \
        */credentials.* | \
        */git-credentials | \
        */keychain-export | \
        */keychain-export.* | \
        */license-key | \
        */license-key.* | \
        */licence-key | \
        */licence-key.* | \
        */activation-state | \
        */activation-state.* | \
        */account-state | \
        */account-state.* | \
        */cookies | \
        */login\ data)
          printf '%s\n' "${relative_path}"
          ;;
      esac
    done
)"
[[ -z "${private_payload_paths}" ]] || {
  echo "The release contains a forbidden package, database, or signing file." >&2
  printf '%s\n' "${private_payload_paths}" >&2
  exit 1
}

secret_pattern='-----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'
secret_text_files="$(
  while IFS= read -r -d '' path; do
    if rg -a -q -- "${secret_pattern}" "${path}"; then
      printf '%s\n' "${path#"${app_path}/"}"
    fi
  done < <(
    find "${app_path}" -type f \
      \( -iname '*.txt' -o -iname '*.md' -o -iname '*.json' -o -iname '*.plist' \
      -o -iname '*.yml' -o -iname '*.yaml' -o -iname '*.ini' -o -iname '*.conf' \) \
      -print0
  )
)"
[[ -z "${secret_text_files}" ]] || {
  echo "The release contains private-key or live-token material in a data file." >&2
  printf '%s\n' "${secret_text_files}" >&2
  exit 1
}

sensitive_state_pattern='"(licenseKey|license_key|licenceKey|licence_key|activation|activationKey|activationToken|password|passphrase|credential|credentials|secret|accessToken|access_token|refreshToken|refresh_token|apiKey|api_key)"[[:space:]]*:[[:space:]]*("[^"[:space:]][^"]*"|[0-9]+|true|\{|\[)|^[[:space:]]*(licenseKey|license_key|licenceKey|licence_key|activation|activationKey|activationToken|password|passphrase|credential|credentials|secret|accessToken|access_token|refreshToken|refresh_token|apiKey|api_key)[[:space:]]*[:=][[:space:]]*[^[:space:]#]+'
sensitive_state_files="$(
  while IFS= read -r -d '' path; do
    if rg -a -i -q -- "${sensitive_state_pattern}" "${path}"; then
      printf '%s\n' "${path#"${app_path}/"}"
    fi
  done < <(
    find "${app_path}" -type f \
      \( -iname '*.json' -o -iname '*.plist' -o -iname '*.yml' -o -iname '*.yaml' \
      -o -iname '*.ini' -o -iname '*.conf' -o -iname '*.properties' \) \
      -print0
  )
)"
[[ -z "${sensitive_state_files}" ]] || {
  echo "The release contains licence, activation, credential, or secret state." >&2
  printf '%s\n' "${sensitive_state_files}" >&2
  exit 1
}

sensitive_tabular_files="$(
  while IFS= read -r -d '' path; do
    if awk -F '[,;\t]' '
      function normalize(value) {
        value = tolower(value)
        gsub(/[^a-z0-9]/, "", value)
        return value
      }
      function sensitive(value) {
        return value ~ /(password|passphrase|passwd|dbpass|pwd|credential|secret|token|apikey|licensekey|licencekey|activation|privatekey|connectionstring|connectionurl|databaseurl|dsn)/
      }
      BEGIN {
        result = 1
        header_seen = 0
        key_column = 0
        value_column = 0
      }
      {
        line = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line == "" || (!header_seen && tolower(line) ~ /^sep[[:space:]]*=/)) {
          next
        }
        if (!header_seen) {
          header_seen = 1
          for (column = 1; column <= NF; column += 1) {
            field = normalize($column)
            if (sensitive(field)) {
              result = 0
              exit
            }
            if (field ~ /^(key|name|setting|property)$/) {
              key_column = column
            }
            if (field ~ /^(value|val)$/) {
              value_column = column
            }
          }
          if (key_column == 0 || value_column == 0) {
            exit
          }
          next
        }
        if (sensitive(normalize($key_column))) {
          result = 0
          exit
        }
      }
      END {
        exit result
      }
    ' "${path}"; then
      printf '%s\n' "${path#"${app_path}/"}"
    fi
  done < <(
    find "${app_path}" -type f \
      \( -iname '*.csv' -o -iname '*.tsv' \) \
      -print0
  )
)"
[[ -z "${sensitive_tabular_files}" ]] || {
  echo "The release contains credential or secret columns in tabular data." >&2
  printf '%s\n' "${sensitive_tabular_files}" >&2
  exit 1
}

echo "Private Personal Release tree is host-only."
