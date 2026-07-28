#!/usr/bin/env bash

set -euo pipefail

release_specification_validate() {
  local release_lock="$1"

  [[ -f "${release_lock}" && ! -L "${release_lock}" ]] || {
    echo "Release Specification input is missing or symlinked: ${release_lock}" >&2
    return 1
  }

  jq -e '
    def nonempty: type == "string" and length > 0;
    def folder_name:
      nonempty
      and . != "."
      and . != ".."
      and (test("[/\\\\]") | not)
      and (explode | all(. >= 32));
    def executable_name:
      type == "string" and test("^[a-z0-9][a-z0-9._-]*$");
    def bundle_identifier:
      type == "string" and test("^[A-Za-z0-9][A-Za-z0-9.-]*\\.[A-Za-z0-9.-]+$");
    def url_scheme:
      type == "string" and test("^[a-z][a-z0-9+.-]*$");
    def timestamp: type == "string" and (try (fromdateiso8601 | type == "number") catch false);
    def version: nonempty and test("^[0-9]+(?:\\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$");
    def git_commit: type == "string" and test("^[0-9a-f]{40}$");
    def sha256: type == "string" and test("^[0-9a-f]{64}$");
    def https_url: type == "string" and startswith("https://");
    def extension_package:
      (.role | nonempty)
      and (.namespace | nonempty)
      and (.name | nonempty)
      and (.id == (.namespace + "." + .name))
      and (.publisher | nonempty)
      and (.version | version)
      and (.engine | nonempty)
      and (.target_platform | nonempty)
      and (.verified_publisher == true)
      and (.pre_release == false)
      and (.deprecated == false)
      and (.registry_api_url | https_url)
      and (.download_url | https_url)
      and (.signature_url | https_url)
      and (.sha256_url | https_url)
      and (.public_key_id | nonempty)
      and (.public_key_url | https_url)
      and (.sha256 | sha256)
      and (.signature_archive_sha256 | sha256)
      and (.public_key_sha256 | sha256)
      and (.package_size | type == "number" and . > 0);

    .schema_version == 6
    and .target == {platform: "darwin", architecture: "arm64"}
    and (.upstream.vscodium.repository | https_url)
    and (.upstream.vscodium.tag | version)
    and (.upstream.vscodium.commit | git_commit)
    and (.upstream.vscodium.published_at | timestamp)
    and (.upstream.vscodium.release_notes_url | https_url)
    and (.upstream.vscodium.release_notes_url == ("https://github.com/VSCodium/vscodium/releases/tag/" + .upstream.vscodium.tag))
    and (.upstream.code_oss.repository | https_url)
    and (.upstream.code_oss.tag | version)
    and (.upstream.code_oss.commit | git_commit)
    and (.upstream.code_oss.published_at | timestamp)
    and (.upstream.code_oss.release_notes_url | https_url)
    and (.upstream.code_oss.release_notes_url == ("https://github.com/microsoft/vscode/releases/tag/" + .upstream.code_oss.tag))
    and (.toolchain.node.version | version)
    and (.toolchain.node.npm_version | version)
    and (.toolchain.node.archive_url | https_url)
    and (.toolchain.node.archive_sha256 | sha256)
    and (.toolchain.python_version | version)
    and (.toolchain.apple_clang_version | version)
    and (.toolchain.macos_sdk_version | version)
    and (.runtime.code_oss_version == .upstream.code_oss.tag)
    and (.runtime.electron_version | version)
    and (.release.wrapper_version | version)
    and (.release.release_set_base_id == ("code-oss-" + .runtime.code_oss_version + "-dbcode-" + .extension.dbcode.version))
    and (.release.compatibility_status | IN("candidate", "approved"))
    and (.release.profile_schema_version | type == "number" and . > 0 and floor == .)
    and (.release.validation_issue | nonempty)
    and .distribution.channel == "github-published-release"
    and (.distribution.repository | nonempty and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
    and .distribution.public_download == true
    and .distribution.dbcode_bundled == false
    and .distribution.release_assets == ["dmg", "checksum"]
    and (.distribution.approved_author_email | nonempty)
    and (.distribution.approved_license_sha256 | sha256)
    and ((.extension.dbcode + {role: "database-client"}) | extension_package)
    and (.extension.dbcode.release_notes_url == ("https://dbcode.io/docs/changelog/" + .extension.dbcode.version))
    and (.extension.dbcode.jq_sorted_compact_contributes_sha256 | sha256)
    and (.extension.python_notebooks.required == true)
    and (.extension.python_notebooks.user_installation_required == false)
    and (.extension.python_notebooks.kernel_runtime | nonempty)
    and (.extension.python_notebooks.packages | type == "array" and length > 0)
    and all(.extension.python_notebooks.packages[]; extension_package)
    and (([.extension.dbcode.id] + [.extension.python_notebooks.packages[].id]) as $package_ids
      | ($package_ids | unique | length) == ($package_ids | length))
    and (.product.app_name | folder_name)
    and (.product.application_name | executable_name)
    and (.product.bundle_identifier | bundle_identifier)
    and (.product.url_scheme | url_scheme)
    and (.product.data_folder_name | folder_name)
    and (.product.user_data_folder_name | folder_name)
    and (.product.extensions_folder_name | folder_name)
    and (.product.shared_data_folder_name | folder_name)
    and (.product.backup_folder_name | folder_name)
    and (.product.storage_namespace | folder_name)
    and (.product.query_folder_name | folder_name)
    and (.product.server_application_name | executable_name)
    and (.product.server_data_folder_name | folder_name)
    and (.product.tunnel_application_name | executable_name)
    and (.product.signing.mode == "local-certificate")
    and (.product.signing.identity_common_name | nonempty)
    and (.product.signing.scope == "current-user-private-use")
    and (.product.focused_shell.enabled == true)
    and (.product.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"})
    and (.product.focused_shell.narrow_breakpoint | type == "number" and . > 0 and floor == .)
    and (.product.darwin_profile_uuid | nonempty)
    and (.product.darwin_profile_payload_uuid | nonempty)
    and (.product.document_extensions == ["sql"])
  ' "${release_lock}" >/dev/null || {
    echo "Release Specification is invalid or uses an unsupported schema: ${release_lock}" >&2
    return 1
  }
}

release_specification_historical_validate() {
  local release_lock="$1"

  [[ -f "${release_lock}" && ! -L "${release_lock}" ]] || {
    echo "Historical Release Specification input is missing or symlinked: ${release_lock}" >&2
    return 1
  }

  jq -e '
    def nonempty: type == "string" and length > 0;
    def timestamp: type == "string" and (try (fromdateiso8601 | type == "number") catch false);
    def version: nonempty and test("^[0-9]+(?:\\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$");
    def git_commit: type == "string" and test("^[0-9a-f]{40}$");
    def sha256: type == "string" and test("^[0-9a-f]{64}$");
    def https_url: type == "string" and startswith("https://");
    def historical_extension_package:
      (.namespace | nonempty)
      and (.name | nonempty)
      and (.id == (.namespace + "." + .name))
      and (.publisher | nonempty)
      and (.version | version)
      and (.engine | nonempty)
      and ((.target_platform // "universal") | nonempty)
      and (.verified_publisher == true)
      and (.pre_release == false)
      and (.deprecated == false)
      and (.registry_api_url | https_url)
      and (.download_url | https_url)
      and (.signature_url | https_url)
      and (.sha256_url | https_url)
      and (.public_key_id | nonempty)
      and (.public_key_url | https_url)
      and (.sha256 | sha256)
      and (.signature_archive_sha256 | sha256)
      and (.public_key_sha256 | sha256)
      and (.package_size | type == "number" and . > 0);
    def historical_notebook_contract:
      .extension.python_notebooks.required == true
      and .extension.python_notebooks.user_installation_required == false
      and (.extension.python_notebooks.kernel_runtime | nonempty)
      and (.extension.python_notebooks.packages | type == "array" and length > 0)
      and all(.extension.python_notebooks.packages[];
        historical_extension_package and (.role | nonempty)
      )
      and (
        ([.extension.dbcode.id] + [.extension.python_notebooks.packages[].id]) as $package_ids
        | ($package_ids | unique | length) == ($package_ids | length)
      );
    def common_historical_contract:
      .target == {platform: "darwin", architecture: "arm64"}
      and (.upstream.vscodium.repository | https_url)
      and (.upstream.vscodium.tag | version)
      and (.upstream.vscodium.commit | git_commit)
      and (
        .upstream.vscodium
        | if has("published_at") then (.published_at | timestamp) else true end
      )
      and (
        .upstream.vscodium
        | if has("release_notes_url") then (.release_notes_url | https_url) else true end
      )
      and (.upstream.code_oss.repository | https_url)
      and (.upstream.code_oss.tag | version)
      and (.upstream.code_oss.commit | git_commit)
      and (
        .upstream.code_oss
        | if has("published_at") then (.published_at | timestamp) else true end
      )
      and (
        .upstream.code_oss
        | if has("release_notes_url") then (.release_notes_url | https_url) else true end
      )
      and (.toolchain.node.version | version)
      and (.toolchain.node.npm_version | version)
      and (.toolchain.node.archive_url | https_url)
      and (.toolchain.node.archive_sha256 | sha256)
      and (.toolchain.python_version | version)
      and (.toolchain.apple_clang_version | version)
      and (.toolchain.macos_sdk_version | version)
      and (.runtime.code_oss_version == .upstream.code_oss.tag)
      and (.runtime.electron_version | version)
      and (.extension.dbcode | historical_extension_package)
      and (
        .extension.dbcode
        | if has("release_notes_url") then (.release_notes_url | https_url) else true end
      )
      and (
        .extension.dbcode
        | if has("jq_sorted_compact_contributes_sha256")
          then (.jq_sorted_compact_contributes_sha256 | sha256)
          else true
          end
      )
      and (.product.app_name | nonempty)
      and (.product.application_name | nonempty)
      and (.product.bundle_identifier | nonempty)
      and (.product.url_scheme | nonempty)
      and (.product.data_folder_name | nonempty)
      and (.product.shared_data_folder_name | nonempty)
      and (.product.server_application_name | nonempty)
      and (.product.server_data_folder_name | nonempty)
      and (.product.tunnel_application_name | nonempty)
      and (.product.focused_shell.enabled == true)
      and (.product.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"})
      and (.product.focused_shell.narrow_breakpoint | type == "number" and . > 0 and floor == .)
      and (.product.darwin_profile_uuid | nonempty)
      and (.product.darwin_profile_payload_uuid | nonempty)
      and .product.document_extensions == ["sql"];
    def schema_2_contract:
      .schema_version == 2
      and (has("release") | not)
      and (
        (.extension | has("python_notebooks") | not)
        or historical_notebook_contract
      )
      and (.product | has("signing") | not);
    def schema_4_contract:
      .schema_version == 4
      and (
        .release.release_set_base_id
          == ("code-oss-" + .runtime.code_oss_version + "-dbcode-" + .extension.dbcode.version)
      )
      and (.release.compatibility_status | IN("candidate", "approved"))
      and (.release.profile_schema_version | type == "number" and . > 0 and floor == .)
      and (.release.validation_issue | nonempty)
      and (.extension.dbcode.target_platform | nonempty)
      and historical_notebook_contract
      and (
        .product
        | if has("signing") then
            .signing.mode == "local-certificate"
            and (.signing.identity_common_name | nonempty)
            and .signing.scope == "current-user-private-use"
          else
            true
          end
      );
    def schema_5_contract:
      .schema_version == 5
      and (
        .release.release_set_base_id
          == ("code-oss-" + .runtime.code_oss_version + "-dbcode-" + .extension.dbcode.version)
      )
      and (.release.compatibility_status | IN("candidate", "approved"))
      and (.release.profile_schema_version | type == "number" and . > 0 and floor == .)
      and (.release.validation_issue | nonempty)
      and (.extension.dbcode.target_platform | nonempty)
      and historical_notebook_contract
      and .product.signing.mode == "local-certificate"
      and (.product.signing.identity_common_name | nonempty)
      and .product.signing.scope == "current-user-private-use";

    common_historical_contract
    and (
      schema_2_contract
      or schema_4_contract
      or schema_5_contract
    )
  ' "${release_lock}" >/dev/null || {
    echo "Historical Release Specification is invalid or unsupported: ${release_lock}" >&2
    return 1
  }
}

release_specification_record() {
  local purpose="$1"
  local release_lock="$2"

  release_specification_validate "${release_lock}" || return 1

  case "${purpose}" in
    build)
      jq -S -c '{
        schema_version: 1,
        target,
        upstream,
        toolchain,
        runtime,
        release,
        distribution,
        product
      }' "${release_lock}"
      ;;
    compiled-host)
      jq -S -c '{
        schema_version: 1,
        target,
        upstream: {
          vscodium: {
            repository: .upstream.vscodium.repository,
            tag: .upstream.vscodium.tag,
            commit: .upstream.vscodium.commit
          },
          code_oss: {
            repository: .upstream.code_oss.repository,
            tag: .upstream.code_oss.tag,
            commit: .upstream.code_oss.commit
          }
        },
        toolchain,
        runtime,
        product: {
          app_name: .product.app_name,
          application_name: .product.application_name,
          bundle_identifier: .product.bundle_identifier,
          url_scheme: .product.url_scheme,
          data_folder_name: .product.data_folder_name,
          shared_data_folder_name: .product.shared_data_folder_name,
          storage_namespace: .product.storage_namespace,
          query_folder_name: .product.query_folder_name,
          server_application_name: .product.server_application_name,
          server_data_folder_name: .product.server_data_folder_name,
          tunnel_application_name: .product.tunnel_application_name,
          focused_shell: .product.focused_shell,
          darwin_profile_uuid: .product.darwin_profile_uuid,
          darwin_profile_payload_uuid: .product.darwin_profile_payload_uuid,
          document_extensions: .product.document_extensions
        }
      }' "${release_lock}"
      ;;
    extensions)
      jq -S -c '{
        schema_version: 1,
        host_code_oss_version: .runtime.code_oss_version,
        dbcode: .extension.dbcode,
        python_notebooks: .extension.python_notebooks,
        packages: (
          [(.extension.dbcode + {role: "database-client"})] +
          .extension.python_notebooks.packages
        )
      }' "${release_lock}"
      ;;
    profile)
      jq -S -c '{
        schema_version: 1,
        target,
        profile_schema_version: .release.profile_schema_version,
        product
      }' "${release_lock}"
      ;;
    identity)
      jq -S -c '{
        schema_version: 1,
        target,
        upstream,
        toolchain,
        runtime,
        product,
        profile_schema_version: .release.profile_schema_version,
        extension,
        runtime_extensions: (
          [(.extension.dbcode + {role: "database-client"})] +
          .extension.python_notebooks.packages
          | map({
              role,
              id,
              version,
              target_platform,
              vsix_sha256: .sha256,
              signature_archive_sha256
            })
          | sort_by(.id, .version)
        )
      }' "${release_lock}"
      ;;
    *)
      echo "Unknown Release Specification purpose: ${purpose}" >&2
      return 2
      ;;
  esac
}

release_specification_historical_record() {
  local purpose="$1"
  local release_lock="$2"

  release_specification_historical_validate "${release_lock}" || return 1

  case "${purpose}" in
    build)
      jq -S -c '
        {
            schema_version: 1,
            target,
            upstream,
            toolchain,
            runtime,
            release,
            product
          }
      ' "${release_lock}"
      ;;
    extensions)
      jq -S -c '
        def dbcode:
          .extension.dbcode
          + {target_platform: (.extension.dbcode.target_platform // "universal")};
        def notebooks:
          .extension.python_notebooks // {
            required: false,
            user_installation_required: false,
            kernel_runtime: "not-in-frozen-release",
            packages: []
          };
        {
          schema_version: 1,
          host_code_oss_version: .runtime.code_oss_version,
          dbcode: dbcode,
          python_notebooks: notebooks,
          packages: ([dbcode + {role: "database-client"}] + notebooks.packages)
        }
      ' "${release_lock}"
      ;;
    profile)
      jq -S -c '{
        schema_version: 1,
        target,
        profile_schema_version: (
          if .schema_version == 2 then 1 else .release.profile_schema_version end
        ),
        product
      }' "${release_lock}"
      ;;
    identity)
      jq -S -c '
        def dbcode:
          .extension.dbcode
          + {
              role: "database-client",
              target_platform: (.extension.dbcode.target_platform // "universal")
            };
        def notebooks:
          (.extension.python_notebooks.packages // []);
        {
          schema_version: 1,
          target,
          upstream,
          toolchain,
          runtime,
          product,
          profile_schema_version: (
            if .schema_version == 2 then 1 else .release.profile_schema_version end
          ),
          extension: (
            .extension
            + {
                dbcode: (dbcode | del(.role)),
                python_notebooks: (
                  .extension.python_notebooks // {
                    required: false,
                    user_installation_required: false,
                    kernel_runtime: "not-in-frozen-release",
                    packages: []
                  }
                )
              }
          ),
          runtime_extensions: (
            [dbcode] + notebooks
            | map({
                role,
                id,
                version,
                target_platform: (.target_platform // "universal"),
                vsix_sha256: .sha256,
                signature_archive_sha256
              })
            | sort_by(.id, .version)
          )
        }
      ' "${release_lock}"
      ;;
    *)
      echo "Unknown historical Release Specification purpose: ${purpose}" >&2
      return 2
      ;;
  esac
}

release_specification_same_dbcode_payload() {
  local current_release_lock="$1"
  local compared_release_lock="$2"

  release_specification_validate "${current_release_lock}" || return 1
  if ! release_specification_validate "${compared_release_lock}" >/dev/null 2>&1 && \
    ! release_specification_historical_validate "${compared_release_lock}" >/dev/null 2>&1; then
    echo "Compared DBCode package has no valid Release Specification." >&2
    return 1
  fi

  jq -e \
    --slurpfile compared "${compared_release_lock}" '
      def dbcode_contract:
        .extension.dbcode
        | {
            id,
            publisher,
            version,
            engine,
            target_platform: (.target_platform // "universal"),
            sha256,
            signature_archive_sha256,
            public_key_id,
            public_key_sha256,
            jq_sorted_compact_contributes_sha256,
            package_size
          };
      dbcode_contract == ($compared[0] | dbcode_contract)
    ' "${current_release_lock}" >/dev/null || {
    echo "The Release Specifications do not describe the same DBCode package and contribution contract." >&2
    return 1
  }
}

release_specification_same_host_build_contract() {
  local current_release_lock="$1"
  local compared_release_lock="$2"

  release_specification_validate "${current_release_lock}" || return 1
  if ! release_specification_validate "${compared_release_lock}" >/dev/null 2>&1 && \
    ! release_specification_historical_validate "${compared_release_lock}" >/dev/null 2>&1; then
    echo "Compared host runtime has no valid Release Specification." >&2
    return 1
  fi

  jq -e \
    --slurpfile compared "${compared_release_lock}" '
      def host_contract:
        {
          target,
          upstream: {
            vscodium: {
              repository: .upstream.vscodium.repository,
              tag: .upstream.vscodium.tag,
              commit: .upstream.vscodium.commit
            },
            code_oss: {
              repository: .upstream.code_oss.repository,
              tag: .upstream.code_oss.tag,
              commit: .upstream.code_oss.commit
            }
          },
          toolchain,
          runtime,
          product: {
            app_name: .product.app_name,
            application_name: .product.application_name,
            bundle_identifier: .product.bundle_identifier,
            url_scheme: .product.url_scheme,
            data_folder_name: .product.data_folder_name,
            shared_data_folder_name: .product.shared_data_folder_name,
            storage_namespace: .product.storage_namespace,
            query_folder_name: .product.query_folder_name,
            server_application_name: .product.server_application_name,
            server_data_folder_name: .product.server_data_folder_name,
            tunnel_application_name: .product.tunnel_application_name,
            signing: .product.signing,
            focused_shell: .product.focused_shell,
            darwin_profile_uuid: .product.darwin_profile_uuid,
            darwin_profile_payload_uuid: .product.darwin_profile_payload_uuid,
            document_extensions: .product.document_extensions
          }
        };
      host_contract == ($compared[0] | host_contract)
    ' "${current_release_lock}" >/dev/null || {
    echo "The Release Specifications do not describe the same pinned host runtime and product identity." >&2
    return 1
  }
}
