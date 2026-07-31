#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/approved_release_set.sh"
source "${script_root}/lib/generated_workspace.sh"

source_repository=""
source_tag=""
release_lock=""
assets_dir=""
publish_confirmed="no"

usage() {
  cat >&2 <<'EOF'
Usage: ./script/publish_release.sh \
  --source-repository DIR \
  --source-tag TAG \
  --release-lock FILE \
  --assets-dir DIR \
  --publish
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-repository) [[ $# -ge 2 ]] || usage; source_repository="$2"; shift ;;
    --source-tag) [[ $# -ge 2 ]] || usage; source_tag="$2"; shift ;;
    --release-lock) [[ $# -ge 2 ]] || usage; release_lock="$2"; shift ;;
    --assets-dir) [[ $# -ge 2 ]] || usage; assets_dir="$2"; shift ;;
    --publish) publish_confirmed="yes" ;;
    *) usage ;;
  esac
  shift
done

[[ -n "${source_repository}" && -n "${source_tag}" && -n "${release_lock}" && \
  -n "${assets_dir}" && "${publish_confirmed}" == "yes" ]] || usage

for command in gh git jq shasum stat; do
  require_command "${command}"
done

source_repository="$(cd "${source_repository}" && pwd -P)"
[[ -d "${source_repository}" && ! -L "${source_repository}" ]] || {
  echo "The source repository is missing or unsafe." >&2
  exit 1
}
git -C "${source_repository}" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "The source repository is not a Git repository." >&2
  exit 1
}
[[ -f "${release_lock}" && ! -L "${release_lock}" ]] || {
  echo "The Release Specification is missing or unsafe: ${release_lock}" >&2
  exit 1
}
"${script_root}/release_specification.sh" validate "${release_lock}" >/dev/null

assets_dir="$(
  generated_workspace_resolve_path \
    "host-release-assets" \
    "${assets_dir}" \
    allow-temporary
)"
[[ -d "${assets_dir}" && ! -L "${assets_dir}" ]] || {
  echo "The release asset directory is missing or unsafe: ${assets_dir}" >&2
  exit 1
}

wrapper_version="$(jq -er '.release.wrapper_version' "${release_lock}")"
repository_slug="$(jq -er '.distribution.repository' "${release_lock}")"
approved_author_email="$(jq -er '.distribution.approved_author_email' "${release_lock}")"
approved_license_sha256="$(jq -er '.distribution.approved_license_sha256' "${release_lock}")"
[[ "${source_tag}" == "v${wrapper_version}" ]] || {
  echo "The source tag must be v${wrapper_version}." >&2
  exit 1
}

[[ -z "$(git -C "${source_repository}" status --porcelain)" ]] || {
  echo "The release repository must be clean." >&2
  exit 1
}
[[ "$(git -C "${source_repository}" branch --show-current)" == "main" ]] || {
  echo "Published releases must come from the main branch." >&2
  exit 1
}
origin_url="$(git -C "${source_repository}" remote get-url origin)"
case "${origin_url}" in
  "https://github.com/${repository_slug}" | \
  "https://github.com/${repository_slug}.git" | \
  "git@github.com:${repository_slug}" | \
  "git@github.com:${repository_slug}.git" | \
  "ssh://git@github.com/${repository_slug}" | \
  "ssh://git@github.com/${repository_slug}.git") ;;
  *)
    echo "The Git origin does not match ${repository_slug}." >&2
    exit 1
    ;;
esac
tag_object="$(git -C "${source_repository}" rev-parse --verify "refs/tags/${source_tag}" 2>/dev/null)" || {
  echo "The annotated source tag does not exist: ${source_tag}" >&2
  exit 1
}
[[ "$(git -C "${source_repository}" cat-file -t "${tag_object}")" == "tag" ]] || {
  echo "The source tag must be annotated: ${source_tag}" >&2
  exit 1
}
source_commit="$(git -C "${source_repository}" rev-parse "${source_tag}^{commit}")"
release_lock_sha256="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
git -C "${source_repository}" merge-base --is-ancestor "${source_commit}" main || {
  echo "The source tag is not contained in main." >&2
  exit 1
}

dmg_files=()
checksum_files=()
compatibility_files=()
verification_files=()
while IFS= read -r -d '' asset; do dmg_files+=("${asset}"); done < <(
  find "${assets_dir}" -mindepth 1 -maxdepth 1 -type f -name '*.dmg' -print0
)
while IFS= read -r -d '' asset; do checksum_files+=("${asset}"); done < <(
  find "${assets_dir}" -mindepth 1 -maxdepth 1 -type f -name '*.dmg.sha256' -print0
)
while IFS= read -r -d '' asset; do compatibility_files+=("${asset}"); done < <(
  find "${assets_dir}" -mindepth 1 -maxdepth 1 -type f -name '*-compatibility.json' -print0
)
while IFS= read -r -d '' asset; do verification_files+=("${asset}"); done < <(
  find "${assets_dir}" -mindepth 1 -maxdepth 1 -type f -name '*-verification.json' -print0
)
[[ "${#dmg_files[@]}" -eq 1 && "${#checksum_files[@]}" -eq 1 && \
  "${#compatibility_files[@]}" -eq 1 && "${#verification_files[@]}" -eq 1 ]] || {
  echo "The release directory must contain one DMG, checksum, compatibility record, and verification receipt." >&2
  exit 1
}
dmg_file="${dmg_files[0]}"
checksum_file="${checksum_files[0]}"
compatibility_file="${compatibility_files[0]}"
verification_file="${verification_files[0]}"

(
  cd "${assets_dir}"
  shasum -a 256 -c "$(basename "${checksum_file}")" >/dev/null
)
dmg_sha256="$(shasum -a 256 "${dmg_file}" | awk '{print $1}')"
dmg_size="$(stat -f '%z' "${dmg_file}")"
checksum_sha256="$(shasum -a 256 "${checksum_file}" | awk '{print $1}')"
checksum_size="$(stat -f '%z' "${checksum_file}")"

jq -e \
  --arg source_tag "${source_tag}" \
  --arg source_commit "${source_commit}" \
  --arg wrapper_version "${wrapper_version}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" '
    .schema_version == 1
    and .scope == "public-host-release"
    and .transfer == {
      channel: "github-published-release",
      draft_required: false,
      public_download: true,
      owned_devices_only: false
    }
    and .source.tag == $source_tag
    and .source.repository_revision == $source_commit
    and .source.release_lock_sha256 == $release_lock_sha256
    and .release.wrapper_version == $wrapper_version
    and (.release.release_set_id | type == "string" and length > 0)
    and .disk_image.filename == $dmg_name
    and .disk_image.sha256 == $dmg_sha256
    and .external_runtime.bundled == false
    and .claims.unofficial_wrapper == true
    and .claims.dbcode_included == false
    and .claims.public_application_release == true
    and .claims.apple_identified_or_notarized == false
  ' "${compatibility_file}" >/dev/null || {
  echo "The compatibility record does not approve a public host-only release." >&2
  exit 1
}
jq -e \
  --arg source_tag "${source_tag}" \
  --arg source_commit "${source_commit}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg release_set_id "$(jq -er '.release.release_set_id' "${compatibility_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" '
    .schema_version == 1
    and .status == "passed"
    and .release_set_id == $release_set_id
    and .source.tag == $source_tag
    and .source.repository_revision == $source_commit
    and .disk_image.sha256 == $dmg_sha256
    and .evidence.release_lock_sha256 == $release_lock_sha256
    and .checks.external_runtime_not_bundled == "passed"
    and .checks.private_data_absent == "passed"
    and .failures == []
  ' "${verification_file}" >/dev/null || {
  echo "The package verification receipt is incomplete or belongs to another release." >&2
  exit 1
}

release_set_id="$(jq -er '.release.release_set_id' "${compatibility_file}")"
history_file="${source_repository}/host/approved-release-history.json"
approved_release_history_validate "${history_file}" >/dev/null
jq -e \
  --arg release_set_id "${release_set_id}" \
  --arg source_tag "${source_tag}" '
    [.approved_release_sets[] |
      select(
        .id == $release_set_id
        and .compatibility_status == "approved"
        and .approval.mode == "prompt-free-public-host-release"
        and .approval.source_tag == $source_tag
      )
    ] | length == 1
  ' "${history_file}" >/dev/null || {
  echo "The exact public host release is not in approved history." >&2
  exit 1
}

"${script_root}/check_public_push_readiness.sh" \
  --repository "${source_repository}" \
  --ref main \
  --approved-author-email "${approved_author_email}" \
  --private-home-name "$(id -un)" \
  --approved-license-sha256 "${approved_license_sha256}"

if existing_release="$(
  gh release view "${source_tag}" \
    --repo "${repository_slug}" \
    --json isDraft,isPrerelease,publishedAt,url 2>/dev/null
)"; then
  echo "A GitHub release already exists for ${source_tag}:" >&2
  jq -r '.url' <<<"${existing_release}" >&2
  exit 1
fi

echo "Pushing main and ${source_tag}..."
git -C "${source_repository}" push --atomic origin \
  main:main \
  "refs/tags/${source_tag}:refs/tags/${source_tag}"

notes_file="$(mktemp "${TMPDIR:-/private/tmp}/dbcode-wrapper-release-notes.XXXXXX")"
cleanup_notes() {
  rm -f "${notes_file}"
}
trap cleanup_notes EXIT INT TERM
code_oss_version="$(jq -er '.runtime.code_oss_version' "${release_lock}")"
dbcode_version="$(jq -er '.extension.dbcode.version' "${release_lock}")"
minimum_macos="$(jq -er '.release.minimum_macos // "12.0"' "${compatibility_file}")"
cat > "${notes_file}" <<EOF
DBCode Wrapper ${source_tag} is an unofficial macOS app that runs the official, unchanged DBCode extension as a focused database application.

The wrapper provides its own app identity, private profile, simplified interface, update status, and verified macOS packaging. DBCode still owns database, notebook, AI, MCP, account, and licence features.

DBCode is not included. You need your own valid DBCode licence. First run obtains the pinned DBCode ${dbcode_version} package from its official Open VSX distribution.

This Apple-silicon build uses Code OSS ${code_oss_version} and requires macOS ${minimum_macos} or later. It is self-signed and is not identified or notarized by Apple. Verify the published SHA-256 before opening it, and use macOS Privacy & Security > Open Anyway if Gatekeeper blocks the first launch.
EOF

echo "Publishing ${source_tag}..."
gh release create "${source_tag}" \
  "${dmg_file}" \
  "${checksum_file}" \
  --repo "${repository_slug}" \
  --verify-tag \
  --title "DBCode Wrapper ${source_tag}" \
  --notes-file "${notes_file}"

release_json="$(
  gh release view "${source_tag}" \
    --repo "${repository_slug}" \
    --json tagName,isDraft,isPrerelease,publishedAt,url,assets
)"
jq -e \
  --arg tag "${source_tag}" \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_digest "sha256:${dmg_sha256}" \
  --argjson dmg_size "${dmg_size}" \
  --arg checksum_name "$(basename "${checksum_file}")" \
  --arg checksum_digest "sha256:${checksum_sha256}" \
  --argjson checksum_size "${checksum_size}" '
    .tagName == $tag
    and .isDraft == false
    and .isPrerelease == false
    and (.publishedAt | type == "string" and length > 0)
    and (.assets | length) == 2
    and any(.assets[];
      .name == $dmg_name and .size == $dmg_size and .digest == $dmg_digest
    )
    and any(.assets[];
      .name == $checksum_name
      and .size == $checksum_size
      and .digest == $checksum_digest
    )
  ' <<<"${release_json}" >/dev/null || {
  echo "GitHub published the release, but its final metadata does not match the local assets." >&2
  exit 1
}

echo "Published host-only release:"
jq -r '.url' <<<"${release_json}"
