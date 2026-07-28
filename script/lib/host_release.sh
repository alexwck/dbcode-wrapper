#!/usr/bin/env bash

if [[ "${DBCODE_WRAPPER_HOST_RELEASE_LIBRARY_LOADED:-}" == "yes" ]]; then
  return 0 2>/dev/null || exit 0
fi
DBCODE_WRAPPER_HOST_RELEASE_LIBRARY_LOADED="yes"

host_release_library_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${host_release_library_root}/lib/release_source_snapshot.sh"

host_release_path_is_within() {
  local root_path="$1"
  local candidate_path="$2"
  local canonical_root canonical_candidate

  canonical_root="$(realpath "${root_path}" 2>/dev/null)" || return 1
  canonical_candidate="$(realpath "${candidate_path}" 2>/dev/null)" || return 1
  case "${canonical_candidate}" in
    "${canonical_root}"/*) return 0 ;;
    *) return 1 ;;
  esac
}

host_release_assert_file() {
  local path="$1"
  local label="$2"
  [[ -f "${path}" && ! -L "${path}" ]] || {
    echo "${label} is missing or unsafe: ${path}" >&2
    return 1
  }
}

host_release_validate_source_tag() {
  local repository="$1"
  local source_tag="$2"
  local manifest_file="$3"
  local release_lock="$4"
  local tag_object tag_commit expected_commit snapshot_json
  local tagged_lock_sha manifest_lock_sha actual_lock_sha

  [[ -d "${repository}" && ! -L "${repository}" ]] || {
    echo "The source repository is missing or unsafe: ${repository}" >&2
    return 1
  }
  git -C "${repository}" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "The source repository is not a Git repository: ${repository}" >&2
    return 1
  }
  git check-ref-format "refs/tags/${source_tag}" >/dev/null 2>&1 || {
    echo "The source tag name is invalid: ${source_tag}" >&2
    return 1
  }

  tag_object="$(git -C "${repository}" rev-parse --verify "refs/tags/${source_tag}" 2>/dev/null)" || {
    echo "The source tag does not exist: ${source_tag}" >&2
    return 1
  }
  [[ "$(git -C "${repository}" cat-file -t "${tag_object}")" == "tag" ]] || {
    echo "The source tag must be annotated: ${source_tag}" >&2
    return 1
  }
  tag_commit="$(git -C "${repository}" rev-parse --verify "refs/tags/${source_tag}^{commit}" 2>/dev/null)" || {
    echo "The source tag does not resolve to a commit: ${source_tag}" >&2
    return 1
  }
  snapshot_json="$(jq -c '.source.snapshot' "${manifest_file}")"
  release_source_snapshot_verify_json "${repository}" "${snapshot_json}" || {
    echo "The build manifest does not contain a valid immutable source snapshot." >&2
    return 1
  }
  expected_commit="$(jq -er '.repository_revision' <<<"${snapshot_json}")"
  [[ "$(jq -er '.source.repository_revision' "${manifest_file}")" == "${expected_commit}" ]] || {
    echo "The manifest source revision does not match its immutable source snapshot." >&2
    return 1
  }
  [[ "${tag_commit}" == "${expected_commit}" ]] || {
    echo "The source tag does not identify the source revision that built the app." >&2
    return 1
  }

  tagged_lock_sha="$(
    git -C "${repository}" show "${tag_commit}:host/release-lock.json" 2>/dev/null |
      shasum -a 256 |
      awk '{print $1}'
  )" || {
    echo "The source tag does not contain the approved release lock." >&2
    return 1
  }
  manifest_lock_sha="$(jq -er '.source.release_lock_sha256' "${manifest_file}")"
  actual_lock_sha="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
  [[ "${tagged_lock_sha}" == "${manifest_lock_sha}" && "${actual_lock_sha}" == "${manifest_lock_sha}" ]] || {
    echo "The source tag, build manifest, and approved release lock do not match." >&2
    return 1
  }

  printf '%s\n' "${tag_commit}"
}

host_release_validate_prompt_free_acceptance() {
  local manifest_file="$1"
  local release_lock="$2"
  local acceptance_file="$3"
  local release_build_spec release_extension_spec release_profile_spec
  local manifest_sha lock_sha expected_installed_extensions

  host_release_assert_file "${manifest_file}" "The build manifest" || return 1
  host_release_assert_file "${release_lock}" "The release lock" || return 1
  host_release_assert_file "${acceptance_file}" "The final acceptance report" || return 1
  if ! declare -F release_specification_validate >/dev/null ||
    ! declare -F release_specification_record >/dev/null; then
    echo "The Release Specification module is unavailable." >&2
    return 1
  fi

  release_specification_validate "${release_lock}" || return 1
  release_build_spec="$(release_specification_record build "${release_lock}")" || return 1
  release_extension_spec="$(release_specification_record extensions "${release_lock}")" || return 1
  release_profile_spec="$(release_specification_record profile "${release_lock}")" || return 1
  manifest_sha="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
  lock_sha="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
  expected_installed_extensions="$(
    jq -c '[.packages[] | (.id + "@" + .version)] | sort' <<<"${release_extension_spec}"
  )"

  jq -e \
    --arg app_name "$(jq -er '.product.app_name' <<<"${release_profile_spec}")" \
    --arg bundle_identifier "$(jq -er '.product.bundle_identifier' <<<"${release_profile_spec}")" \
    --arg architecture "$(jq -er '.target.architecture' <<<"${release_build_spec}")" \
    --arg app_sha "$(jq -er '.artifact.sha256' "${manifest_file}")" \
    --argjson installed_size_kib "$(jq -er '.packaging.installed_kib' "${manifest_file}")" \
    --arg manifest_sha "${manifest_sha}" \
    --arg lock_sha "${lock_sha}" \
    --arg code_oss_version "$(jq -er '.runtime.code_oss_version' <<<"${release_build_spec}")" \
    --arg dbcode_id "$(jq -er '.dbcode.id' <<<"${release_extension_spec}")" \
    --arg dbcode_version "$(jq -er '.dbcode.version' <<<"${release_extension_spec}")" \
    --arg dbcode_sha256 "$(jq -er '.dbcode.sha256' <<<"${release_extension_spec}")" \
    --arg signature_requirement "$(jq -er '.artifact.signature_requirement' "${manifest_file}")" \
    --arg certificate_sha1 "$(jq -er '.artifact.signing_certificate_sha1' "${manifest_file}")" \
    --arg certificate_sha256 "$(jq -er '.artifact.signing_certificate_sha256' "${manifest_file}")" \
    --arg source_revision "$(jq -er '.source.snapshot.repository_revision' "${manifest_file}")" \
    --arg source_tree_oid "$(jq -er '.source.snapshot.tree_oid' "${manifest_file}")" \
    --arg source_snapshot_sha256 "$(jq -er '.source.snapshot.snapshot_sha256' "${manifest_file}")" \
    --arg compiled_host_input_id "$(jq -er '.source.compiled_host.input_id' "${manifest_file}")" \
    --arg release_set_id "$(jq -er '.release.release_set_id' "${manifest_file}")" \
    --argjson expected_installed_extensions "${expected_installed_extensions}" '
      .schema_version == 3
      and .status == "passed"
      and .scope == "current-user-private-use"
      and .source == {
        repository_revision: $source_revision,
        tree_oid: $source_tree_oid,
        snapshot_sha256: $source_snapshot_sha256,
        compiled_host_input_id: $compiled_host_input_id
      }
      and .release == {
        release_set_id: $release_set_id,
        app_name: $app_name,
        bundle_identifier: $bundle_identifier,
        platform: "darwin",
        architecture: $architecture,
        app_sha256: $app_sha,
        installed_size_kib: $installed_size_kib,
        code_oss_version: $code_oss_version,
        dbcode: {
          id: $dbcode_id,
          version: $dbcode_version,
          vsix_sha256: $dbcode_sha256
        },
        installed_extensions: $expected_installed_extensions
      }
      and .evidence_sha256.build_manifest == $manifest_sha
      and .evidence_sha256.release_lock == $lock_sha
      and (.evidence_sha256 | keys | sort) == [
        "build_manifest",
        "development_log",
        "release_lock",
        "rendered_report",
        "smoke_log"
      ]
      and all(.evidence_sha256[]; type == "string" and test("^[0-9a-f]{64}$"))
      and .gates == {
        development_contracts: "passed",
        strict_signature_and_manifest: "passed",
        signed_app_one_profile_launch: "passed",
        dbcode_focused_rendered_interface: "passed",
        exact_external_extension_inventory: "passed",
        prompt_free_automation: "passed",
        bundle_unchanged_after_use: "passed"
      }
      and .gate_execution == {
        source_snapshot_sha256: $source_snapshot_sha256,
        release_set_id: $release_set_id,
        app_sha256: $app_sha,
        build_manifest_sha256: $manifest_sha,
        development_runner: "script/check_development.sh",
        static_smoke_runner: "script/smoke_host.sh"
      }
      and .automation == {
        profile_name: "qa",
        persistent_profile: true,
        person_controlled_actions: "not-invoked",
        kernel_started: false,
        sql_executed: false,
        model_called: false,
        secret_entered: false
      }
      and (.rendered_evidence.check_count | type == "number" and . >= 8)
      and (.rendered_evidence.known_warning_count | type == "number" and . >= 0)
      and .rendered_evidence.unexpected_error_count == 0
      and .signing.kind == "certificate"
      and .signing.scope == "current-user-private-use"
      and .signing.designated_requirement == $signature_requirement
      and .signing.certificate.sha1 == $certificate_sha1
      and .signing.certificate.sha256 == $certificate_sha256
      and (. | has("manual_evidence") | not)
      and .failures == []
      and .waivers == []
      and .distribution_claims == {
        developer_id: false,
        notarized: false,
        public_distribution_ready: false,
        intel_support: false,
        multi_user_support: false,
        official_dbcode_endorsement: false
      }
      and (.completed_at_utc | type == "string" and length > 0)
      and (.private_use_risks | type == "array" and length >= 5)
      and all(.private_use_risks[]; type == "string" and length > 0)
    ' "${acceptance_file}" >/dev/null || {
    echo "The prompt-free acceptance report is incomplete or belongs to another artifact." >&2
    return 1
  }
}

host_release_prompt_free_acceptance_record() {
  local manifest_file="$1"
  local release_lock="$2"
  local acceptance_file="$3"

  host_release_validate_prompt_free_acceptance \
    "${manifest_file}" \
    "${release_lock}" \
    "${acceptance_file}" || return 1

  jq -S -c \
    --arg acceptance_sha256 "$(shasum -a 256 "${acceptance_file}" | awk '{print $1}')" \
    --arg build_manifest_sha256 "$(shasum -a 256 "${manifest_file}" | awk '{print $1}')" \
    --arg release_lock_sha256 "$(shasum -a 256 "${release_lock}" | awk '{print $1}')" \
    --arg release_set_id "$(jq -er '.release.release_set_id' "${manifest_file}")" '
      {
        schema_version: 1,
        status: "validated",
        acceptance_schema_version: 3,
        acceptance_sha256: $acceptance_sha256,
        build_manifest_sha256: $build_manifest_sha256,
        release_lock_sha256: $release_lock_sha256,
        release_set_id: $release_set_id
      }
    ' <<<"{}"
}

host_release_validate_sources() {
  local app_path="$1"
  local manifest_file="$2"
  local release_lock="$3"
  local acceptance_file="$4"
  local info_plist="${app_path}/Contents/Info.plist"
  local app_sha manifest_sha lock_sha
  local expected_requirement actual_requirement signature_details
  local expected_extensions accepted_extensions architectures
  local code_oss_version dbcode_version dbcode_sha256
  local runtime_setup_manifest runtime_setup_logic runtime_setup_sha256
  local release_build_spec release_extension_spec release_profile_spec
  local expected_setup_packages actual_setup_packages
  local expected_manifest_extensions actual_manifest_extensions
  local node_binary

  [[ -d "${app_path}" && ! -L "${app_path}" ]] || {
    echo "The signed host application is missing or unsafe: ${app_path}" >&2
    return 1
  }
  host_release_assert_file "${manifest_file}" "The build manifest" || return 1
  host_release_assert_file "${release_lock}" "The release lock" || return 1
  host_release_assert_file "${acceptance_file}" "The final acceptance report" || return 1
  host_release_assert_file "${info_plist}" "The application Info.plist" || return 1

  if ! declare -F release_specification_validate >/dev/null ||
    ! declare -F release_specification_record >/dev/null; then
    echo "The Release Specification module is unavailable." >&2
    return 1
  fi
  release_specification_validate "${release_lock}" || return 1
  release_build_spec="$(release_specification_record build "${release_lock}")" || return 1
  release_extension_spec="$(release_specification_record extensions "${release_lock}")" || return 1
  release_profile_spec="$(release_specification_record profile "${release_lock}")" || return 1

  app_sha="$(artifact_digest "${app_path}")"
  manifest_sha="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
  lock_sha="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"

  jq -e \
    --arg app_sha "${app_sha}" \
    --arg lock_sha "${lock_sha}" \
    --arg app_name "$(jq -er '.product.app_name' <<<"${release_profile_spec}")" \
    --arg bundle_identifier "$(jq -er '.product.bundle_identifier' <<<"${release_profile_spec}")" \
    --arg architecture "$(jq -er '.target.architecture' <<<"${release_build_spec}")" \
    --arg code_oss_version "$(jq -er '.runtime.code_oss_version' <<<"${release_build_spec}")" \
    --arg vscodium_version "$(jq -er '.upstream.vscodium.tag' <<<"${release_build_spec}")" \
    --arg compatibility_status "$(jq -er '.release.compatibility_status' <<<"${release_build_spec}")" \
    --arg wrapper_version "$(jq -er '.release.wrapper_version' <<<"${release_build_spec}")" '
      .schema_version == 6
      and .release.wrapper_version == $wrapper_version
      and .release.compatibility_status == $compatibility_status
      and (.release.release_set_id | type == "string" and length > 0)
      and .source.release_lock_sha256 == $lock_sha
      and .source.repository_revision == .source.snapshot.repository_revision
      and .source.release_lock_sha256 == .source.snapshot.release_lock_sha256
      and .source.overlay_sha256 == .source.snapshot.host_script_sha256
      and .source.snapshot.schema_version == 1
      and .source.snapshot.mode == "immutable-git-commit"
      and (.source.snapshot.tree_oid | test("^[0-9a-f]{40}$"))
      and (.source.snapshot.snapshot_sha256 | test("^[0-9a-f]{64}$"))
      and .source.compiled_host.schema_version == 2
      and (.source.compiled_host.input_id | test("^compiled-host-[0-9a-f]{64}$"))
      and (.source.compiled_host.source_revision | test("^[0-9a-f]{40}$"))
      and .source.compiled_host.app_digest_algorithm == "sha256-files-modes-links-v1"
      and (.source.compiled_host.app_sha256 | test("^[0-9a-f]{64}$"))
      and .source.compiled_host.compilation_environment.schema_version == 1
      and (.source.compiled_host.cache_status | IN("hit", "miss-built"))
      and .runtime.code_oss == $code_oss_version
      and .runtime.host == $vscodium_version
      and .artifact.app_name == $app_name
      and .artifact.bundle_identifier == $bundle_identifier
      and .artifact.platform == "darwin"
      and .artifact.architecture == $architecture
      and .artifact.sha256 == $app_sha
      and .artifact.signature_kind == "certificate"
      and (.artifact.signature_requirement | type == "string" and length > 0)
      and .artifact.signature_scope == "current-user-private-use"
      and .packaging.status == "built-and-signed"
      and .packaging.updater_enabled == false
      and .packaging.external_runtime_in_app == false
      and .packaging.external_runtime_setup == "focused-pinned-official-sources"
      and (.packaging.external_runtime_setup_manifest_sha256 | test("^[0-9a-f]{64}$"))
      and (.runtime_extensions | type == "array" and length > 0)
      and all(.runtime_extensions[];
        .required == true
        and .verified_publisher == true
        and .install_location == "external-private-profile"
      )
      and ([.runtime_extensions[] | select(.id == "dbcode.dbcode")] | length) == 1
    ' "${manifest_file}" >/dev/null || {
    echo "The build manifest does not describe a release-ready host-only candidate with focused first-run runtime setup." >&2
    return 1
  }

  runtime_setup_manifest="${app_path}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json"
  runtime_setup_logic="${app_path}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js"
  host_release_assert_file "${runtime_setup_manifest}" "The focused first-run runtime setup manifest" || return 1
  host_release_assert_file "${runtime_setup_logic}" "The focused first-run runtime setup validator" || return 1
  [[ -n "${NODE_BIN_DIR:-}" && -x "${NODE_BIN_DIR}/node" ]] || {
    echo "The pinned Node.js runtime is unavailable for focused setup validation." >&2
    return 1
  }
  node_binary="${NODE_BIN_DIR}/node"
  "${node_binary}" -e '
    const fs = require("node:fs");
    const path = require("node:path");
    const [logic, record] = process.argv.slice(1);
    require(path.resolve(logic)).validateRuntimeConfiguration(JSON.parse(fs.readFileSync(record, "utf8")));
  ' "${runtime_setup_logic}" "${runtime_setup_manifest}" || {
    echo "The focused first-run runtime setup manifest is invalid." >&2
    return 1
  }
  runtime_setup_sha256="$(shasum -a 256 "${runtime_setup_manifest}" | awk '{print $1}')"
  [[ "${runtime_setup_sha256}" == "$(jq -er '.packaging.external_runtime_setup_manifest_sha256' "${manifest_file}")" ]] || {
    echo "The focused first-run runtime setup manifest does not match the accepted app." >&2
    return 1
  }
  expected_setup_packages="$(
    jq -S -c '
      .packages
      | map({
          role,
          namespace,
          name,
          id,
          publisher,
          version,
          engine,
          target_platform,
          published_at,
          verified_publisher,
          pre_release,
          deprecated,
          registry_api_url,
          download_url,
          signature_url,
          sha256_url,
          public_key_id,
          public_key_url,
          sha256,
          signature_archive_sha256,
          public_key_sha256,
          package_size
        })
      | sort_by(.id)
    ' <<<"${release_extension_spec}"
  )"
  actual_setup_packages="$(jq -S -c '.packages | sort_by(.id)' "${runtime_setup_manifest}")"
  jq -e \
    --arg code_oss_version "$(jq -er '.runtime.code_oss_version' <<<"${release_build_spec}")" \
    --arg application_name "$(jq -er '.product.application_name' <<<"${release_profile_spec}")" '
      .code_oss_version == $code_oss_version
      and .application_name == $application_name
    ' "${runtime_setup_manifest}" >/dev/null || {
    echo "The focused first-run setup host identity does not match the supplied Release Specification." >&2
    return 1
  }
  [[ "${actual_setup_packages}" == "${expected_setup_packages}" ]] || {
    echo "The focused first-run setup does not match the supplied Release Specification." >&2
    return 1
  }
  expected_manifest_extensions="$(
    jq -S -c '
      [
        .packages[] | {
          role,
          id,
          version,
          target_platform,
          verified_publisher,
          vsix_sha256: .sha256,
          signature_archive_sha256,
          public_key_id,
          public_key_sha256,
          install_location: "external-private-profile",
          required: true
        }
      ] | sort_by(.id)
    ' <<<"${release_extension_spec}"
  )"
  actual_manifest_extensions="$(jq -S -c '.runtime_extensions | sort_by(.id)' "${manifest_file}")"
  [[ "${actual_manifest_extensions}" == "${expected_manifest_extensions}" ]] || {
    echo "The build manifest extension inventory does not match the supplied Release Specification." >&2
    return 1
  }

  code_oss_version="$(jq -er '.runtime.code_oss' "${manifest_file}")"
  dbcode_version="$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .version' "${manifest_file}")"
  dbcode_sha256="$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .vsix_sha256' "${manifest_file}")"

  acceptance_schema="$(jq -er '.schema_version' "${acceptance_file}")"
  if [[ "${acceptance_schema}" == "3" ]]; then
    host_release_validate_prompt_free_acceptance \
      "${manifest_file}" \
      "${release_lock}" \
      "${acceptance_file}" || return 1
  else
    jq -e \
    --arg app_sha "${app_sha}" \
    --arg manifest_sha "${manifest_sha}" \
    --arg lock_sha "${lock_sha}" \
    --arg code_oss_version "${code_oss_version}" \
    --arg dbcode_version "${dbcode_version}" \
    --arg dbcode_sha256 "${dbcode_sha256}" \
    --arg signature_requirement "$(jq -er '.artifact.signature_requirement' "${manifest_file}")" \
    --arg certificate_sha1 "$(jq -er '.artifact.signing_certificate_sha1' "${manifest_file}")" \
    --arg certificate_sha256 "$(jq -er '.artifact.signing_certificate_sha256' "${manifest_file}")" \
    --arg release_set_id "$(jq -er '.release.release_set_id' "${manifest_file}")" '
      (.schema_version == 1 or .schema_version == 2)
      and .status == "passed"
      and .scope == "current-user-private-use"
      and .release.release_set_id == $release_set_id
      and .release.app_sha256 == $app_sha
      and .release.platform == "darwin"
      and .release.architecture == "arm64"
      and .release.code_oss_version == $code_oss_version
      and .release.dbcode.id == "dbcode.dbcode"
      and .release.dbcode.version == $dbcode_version
      and .release.dbcode.vsix_sha256 == $dbcode_sha256
      and .evidence_sha256.build_manifest == $manifest_sha
      and .evidence_sha256.release_lock == $lock_sha
      and (.evidence_sha256 | keys | sort) == [
        "build_manifest",
        "compatibility_matrix",
        "development_log",
        "real_profile_proof",
        "release_lock",
        "rendered_report",
        "restart_health",
        "rollback",
        "signing_continuity",
        "smoke_log"
      ]
      and all(.evidence_sha256[]; type == "string" and test("^[0-9a-f]{64}$"))
      and (
        if .schema_version == 1 then
          .gates == {
            development_contracts: "passed",
            strict_signature_and_manifest: "passed",
            rebuilt_host_safe_storage_behavior: "accepted-limitation",
            independent_launch_and_profile_isolation: "passed",
            dbcode_focused_rendered_interface: "passed",
            exact_external_extension_inventory: "passed",
            lifetime_entitlement_and_persistence: "passed",
            protected_credential_reentry: "passed",
            read_only_update_discovery: "passed",
            postgresql_read_only: "passed",
            duckdb_and_parquet: "passed",
            first_run_migration_and_hyphen_path: "passed",
            four_way_update_compatibility: "passed",
            promotion_restart_health: "passed",
            complete_set_rollback: "passed",
            owner_only_profile_permissions: "passed",
            bundle_unchanged_after_use: "passed"
          }
          and (.manual_evidence | keys | sort) == [
            "activation",
            "credential_reentry",
            "duckdb",
            "parquet",
            "persistence",
            "postgresql",
            "update_discovery"
          ]
        else
          .gates == {
            development_contracts: "passed",
            strict_signature_and_manifest: "passed",
            rebuilt_host_safe_storage_behavior: "accepted-limitation",
            independent_launch_and_profile_isolation: "passed",
            dbcode_focused_rendered_interface: "passed",
            exact_external_extension_inventory: "passed",
            lifetime_entitlement_and_persistence: "passed",
            protected_credential_reentry: "passed",
            read_only_update_discovery: "passed",
            postgresql_read_only: "passed",
            stored_routine_debugger: "passed",
            duckdb_and_parquet: "passed",
            first_run_migration_and_hyphen_path: "passed",
            four_way_update_compatibility: "passed",
            promotion_restart_health: "passed",
            complete_set_rollback: "passed",
            owner_only_profile_permissions: "passed",
            bundle_unchanged_after_use: "passed"
          }
          and (.manual_evidence | keys | sort) == [
            "activation",
            "credential_reentry",
            "debugger",
            "duckdb",
            "parquet",
            "persistence",
            "postgresql",
            "update_discovery"
          ]
        end
      )
      and all(.manual_evidence[];
        .status == "passed"
        and .launch_kind == "relaunch"
        and (.expected_result | type == "string" and length > 0)
        and (.note | type == "string" and length > 0)
        and (.recorded_at | type == "string" and length > 0)
      )
      and (.rendered_evidence.check_count | type == "number" and . >= 35)
      and (.rendered_evidence.known_warning_count | type == "number" and . >= 0)
      and .rendered_evidence.unexpected_error_count == 0
      and .signing.kind == "certificate"
      and .signing.scope == "current-user-private-use"
      and .signing.designated_requirement == $signature_requirement
      and .signing.certificate.sha1 == $certificate_sha1
      and .signing.certificate.sha256 == $certificate_sha256
      and .signing.cryptographic_identity_stable_across_rebuilds == true
      and .signing.safe_storage_access_stable_across_rebuilds == false
      and .signing.safe_storage_prompt_observation == "accepted-new-approval-after-distinct-rebuild"
      and .signing.safe_storage_rebuild_behavior == "manual-approval-may-repeat-after-host-rebuild"
      and .failures == []
      and .waivers == []
      and .distribution_claims == {
        developer_id: false,
        notarized: false,
        public_distribution_ready: false,
        intel_support: false,
        multi_user_support: false,
        official_dbcode_endorsement: false
      }
      and (.completed_at_utc | type == "string" and length > 0)
      and (.private_use_risks | type == "array" and length >= 6)
    ' "${acceptance_file}" >/dev/null || {
    echo "The final acceptance report is incomplete or does not approve this exact private-use artifact." >&2
    return 1
    }
  fi

  expected_extensions="$(
    jq -c '[.runtime_extensions[] | "\(.id)@\(.version)"] | sort' "${manifest_file}"
  )"
  accepted_extensions="$(jq -c '.release.installed_extensions | sort' "${acceptance_file}")"
  [[ "${accepted_extensions}" == "${expected_extensions}" ]] || {
    echo "The accepted external extension inventory does not match the build manifest." >&2
    return 1
  }

  [[ "$(plutil -extract CFBundleName raw "${info_plist}")" == "DBCode Wrapper" ]] || {
    echo "The packaged application has an unexpected name." >&2
    return 1
  }
  [[ "$(plutil -extract CFBundleIdentifier raw "${info_plist}")" == "io.alexabelle.dbcodewrapper" ]] || {
    echo "The packaged application has an unexpected bundle identifier." >&2
    return 1
  }

  architectures="$(lipo -archs "${app_path}/Contents/MacOS/$(plutil -extract CFBundleExecutable raw "${info_plist}")")"
  [[ "${architectures}" == "arm64" ]] || {
    echo "The Host release must contain only the Apple-silicon host." >&2
    return 1
  }

  codesign --verify --deep --strict --verbose=2 "${app_path}"
  expected_requirement="$(jq -er '.artifact.signature_requirement' "${manifest_file}")"
  actual_requirement="$(codesign -d -r- "${app_path}" 2>&1 | sed -n '/^designated => /p')"
  [[ "${actual_requirement}" == "${expected_requirement}" ]] || {
    echo "The packaged application has an unexpected signing requirement." >&2
    return 1
  }
  signature_details="$(codesign -dvvv "${app_path}" 2>&1)"
  [[ "${signature_details}" != *'Signature=adhoc'* ]] || {
    echo "The packaged application is ad-hoc signed." >&2
    return 1
  }

  for notice_path in \
    "${app_path}/Contents/Resources/app/LICENSE.txt" \
    "${app_path}/Contents/Resources/app/ThirdPartyNotices.txt" \
    "${app_path}/Contents/Resources/LICENSES.chromium.html"; do
    host_release_assert_file "${notice_path}" "A required upstream notice" || return 1
  done
}

host_release_write_compatibility_manifest() {
  local output_file="$1"
  local created_at_utc="$2"
  local manifest_file="$3"
  local release_lock="$4"
  local acceptance_file="$5"
  local source_tag="$6"
  local source_commit="$7"
  local dmg_name="$8"
  local dmg_sha256="$9"
  local dmg_size_bytes="${10}"
  local guide_name="${11}"
  local guide_sha256="${12}"
  local checksum_name="${13}"
  local compatibility_name="${14}"
  local notes_name="${15}"
  local verification_name="${16}"
  local minimum_macos="${17}"

  jq -n \
    --arg created_at_utc "${created_at_utc}" \
    --arg source_tag "${source_tag}" \
    --arg source_commit "${source_commit}" \
    --arg source_tree_oid "$(jq -er '.source.snapshot.tree_oid' "${manifest_file}")" \
    --arg source_snapshot_sha256 "$(jq -er '.source.snapshot.snapshot_sha256' "${manifest_file}")" \
    --arg compiled_host_input_id "$(jq -er '.source.compiled_host.input_id' "${manifest_file}")" \
    --arg release_set_id "$(jq -er '.release.release_set_id' "${manifest_file}")" \
    --arg source_set_id "$(jq -er '.release.source_set_id' "${manifest_file}")" \
    --arg wrapper_version "$(jq -er '.release.wrapper_version' "${release_lock}")" \
    --arg code_oss_version "$(jq -er '.runtime.code_oss' "${manifest_file}")" \
    --arg vscodium_version "$(jq -er '.runtime.host' "${manifest_file}")" \
    --arg dbcode_version "$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .version' "${manifest_file}")" \
    --arg architecture "$(jq -er '.artifact.architecture' "${manifest_file}")" \
    --arg minimum_macos "${minimum_macos}" \
    --arg app_name "DBCode Wrapper.app" \
    --arg app_sha256 "$(jq -er '.artifact.sha256' "${manifest_file}")" \
    --arg bundle_identifier "$(jq -er '.artifact.bundle_identifier' "${manifest_file}")" \
    --arg signature_requirement "$(jq -er '.artifact.signature_requirement' "${manifest_file}")" \
    --arg dmg_name "${dmg_name}" \
    --arg dmg_sha256 "${dmg_sha256}" \
    --argjson dmg_size_bytes "${dmg_size_bytes}" \
    --arg guide_name "${guide_name}" \
    --arg guide_sha256 "${guide_sha256}" \
    --arg checksum_name "${checksum_name}" \
    --arg compatibility_name "${compatibility_name}" \
    --arg notes_name "${notes_name}" \
    --arg verification_name "${verification_name}" \
    --arg manifest_sha256 "$(shasum -a 256 "${manifest_file}" | awk '{print $1}')" \
    --arg release_lock_sha256 "$(shasum -a 256 "${release_lock}" | awk '{print $1}')" \
    --arg acceptance_sha256 "$(shasum -a 256 "${acceptance_file}" | awk '{print $1}')" \
    --argjson runtime_extensions "$(jq '[.runtime_extensions[] | {id, version, target_platform, vsix_sha256, signature_archive_sha256, public_key_id, public_key_sha256}] | sort_by(.id)' "${manifest_file}")" '
      {
        schema_version: 1,
        created_at_utc: $created_at_utc,
        scope: "public-host-release",
        transfer: {
          channel: "github-published-release",
          draft_required: false,
          public_download: true,
          owned_devices_only: false
        },
        source: {
          tag: $source_tag,
          repository_revision: $source_commit,
          tree_oid: $source_tree_oid,
          snapshot_sha256: $source_snapshot_sha256,
          release_lock_sha256: $release_lock_sha256,
          compiled_host_input_id: $compiled_host_input_id
        },
        release: {
          wrapper_version: $wrapper_version,
          release_set_id: $release_set_id,
          source_set_id: $source_set_id,
          code_oss_version: $code_oss_version,
          vscodium_version: $vscodium_version,
          dbcode_version: $dbcode_version,
          architecture: $architecture,
          minimum_macos: $minimum_macos
        },
        app: {
          filename: $app_name,
          sha256: $app_sha256,
          bundle_identifier: $bundle_identifier,
          signature: {
            kind: "current-user-self-signed-certificate",
            designated_requirement: $signature_requirement,
            developer_id: false,
            notarized: false
          }
        },
        disk_image: {
          filename: $dmg_name,
          sha256: $dmg_sha256,
          size_bytes: $dmg_size_bytes,
          format: "UDZO",
          filesystem: "HFS+",
          read_only: true,
          volume_name: "DBCode Wrapper",
          contents: [$app_name, $guide_name],
          install_guide_sha256: $guide_sha256
        },
        external_runtime: {
          bundled: false,
          setup: "focused-pinned-official-sources",
          source: "official-open-vsx",
          packages: $runtime_extensions
        },
        evidence: {
          build_manifest_sha256: $manifest_sha256,
          release_lock_sha256: $release_lock_sha256,
          final_acceptance_sha256: $acceptance_sha256,
          final_acceptance_status: "passed"
        },
        assets: {
          checksum: $checksum_name,
          compatibility: $compatibility_name,
          install_and_rollback: $notes_name,
          verification: $verification_name
        },
        claims: {
          unofficial_wrapper: true,
          dbcode_included: false,
          licence_or_profile_included: false,
          public_application_release: true,
          apple_identified_or_notarized: false
        }
      }
    ' > "${output_file}"
}

host_release_validate_compatibility_manifest() {
  local compatibility_file="$1"
  local expected_file="$2"

  jq -e -S . "${compatibility_file}" >/dev/null || {
    echo "The compatibility manifest is not valid JSON." >&2
    return 1
  }
  cmp -s <(jq -S . "${compatibility_file}") <(jq -S . "${expected_file}") || {
    echo "The compatibility manifest does not describe this exact host release." >&2
    return 1
  }
}

host_release_assert_sanitized_metadata() {
  local metadata_file
  local secret_pattern='-----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'
  local private_path_pattern='/(Users|home)/[A-Za-z0-9._-]+/|/(private/)?var/folders/'

  for metadata_file in "$@"; do
    host_release_assert_file "${metadata_file}" "A release metadata asset" || return 1
    if rg -a -q -- "${secret_pattern}|${private_path_pattern}" "${metadata_file}"; then
      echo "A release metadata asset contains a private path, private key, or live-token pattern: ${metadata_file}" >&2
      return 1
    fi
  done
}
