def release_specification_build_record:
  {
    schema_version: 1,
    target,
    upstream,
    toolchain,
    runtime,
    release,
    distribution,
    product
  };

def release_specification_compiled_host_record:
  {
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
  };

def release_specification_extension_record:
  {
    schema_version: 1,
    host_code_oss_version: .runtime.code_oss_version,
    dbcode: .extension.dbcode,
    python_notebooks: .extension.python_notebooks,
    packages: (
      [(.extension.dbcode + {role: "database-client"})] +
      .extension.python_notebooks.packages
    )
  };

def release_specification_profile_record:
  {
    schema_version: 1,
    target,
    profile_schema_version: .release.profile_schema_version,
    product
  };

def release_specification_identity_record:
  {
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
  };

def release_specification_record($purpose):
  if $purpose == "build" then release_specification_build_record
  elif $purpose == "compiled-host" then release_specification_compiled_host_record
  elif $purpose == "extensions" then release_specification_extension_record
  elif $purpose == "profile" then release_specification_profile_record
  elif $purpose == "identity" then release_specification_identity_record
  else error("Unknown Release Specification purpose: \($purpose)")
  end;

def release_specification_canonical:
  if type == "object" then
    to_entries
    | sort_by(.key)
    | map({key: .key, value: (.value | release_specification_canonical)})
    | from_entries
  elif type == "array" then
    map(release_specification_canonical)
  else
    .
  end;

def release_specification_compact_json:
  release_specification_canonical | tojson;

def release_specification_host_config:
  (release_specification_build_record) as $build
  | (release_specification_extension_record) as $extensions
  | (release_specification_profile_record) as $profile
  | {
      RELEASE_BUILD_SPEC: ($build | release_specification_compact_json),
      RELEASE_EXTENSION_SPEC: ($extensions | release_specification_compact_json),
      RELEASE_PROFILE_SPEC: ($profile | release_specification_compact_json),
      APP_NAME: $profile.product.app_name,
      APPLICATION_NAME: $profile.product.application_name,
      BUNDLE_IDENTIFIER: $profile.product.bundle_identifier,
      URL_SCHEME: $profile.product.url_scheme,
      DATA_FOLDER_NAME: $profile.product.data_folder_name,
      USER_DATA_FOLDER_NAME: $profile.product.user_data_folder_name,
      EXTENSIONS_FOLDER_NAME: $profile.product.extensions_folder_name,
      SHARED_DATA_FOLDER_NAME: $profile.product.shared_data_folder_name,
      BACKUP_FOLDER_NAME: $profile.product.backup_folder_name,
      STORAGE_NAMESPACE: $profile.product.storage_namespace,
      QUERY_FOLDER_NAME: $profile.product.query_folder_name,
      SERVER_APPLICATION_NAME: $profile.product.server_application_name,
      SERVER_DATA_FOLDER_NAME: $profile.product.server_data_folder_name,
      TUNNEL_APPLICATION_NAME: $profile.product.tunnel_application_name,
      SIGNING_MODE: $profile.product.signing.mode,
      SIGNING_IDENTITY_COMMON_NAME: $profile.product.signing.identity_common_name,
      SIGNING_SCOPE: $profile.product.signing.scope,
      FOCUSED_SHELL_ENABLED: ($profile.product.focused_shell.enabled | tostring),
      FOCUSED_SHELL_RESULT_LOCATION: $profile.product.focused_shell.result_location,
      FOCUSED_SHELL_NARROW_BREAKPOINT: ($profile.product.focused_shell.narrow_breakpoint | tostring),
      DARWIN_PROFILE_UUID: $profile.product.darwin_profile_uuid,
      DARWIN_PROFILE_PAYLOAD_UUID: $profile.product.darwin_profile_payload_uuid,
      DOCUMENT_EXTENSIONS: ($profile.product.document_extensions | release_specification_compact_json),
      PROFILE_SCHEMA_VERSION: ($profile.profile_schema_version | tostring),
      TARGET_ARCH: $build.target.architecture,
      VSCODIUM_TAG: $build.upstream.vscodium.tag,
      VSCODIUM_COMMIT: $build.upstream.vscodium.commit,
      VSCODIUM_REPOSITORY: $build.upstream.vscodium.repository,
      VSCODIUM_PUBLISHED_AT: $build.upstream.vscodium.published_at,
      VSCODIUM_RELEASE_NOTES_URL: $build.upstream.vscodium.release_notes_url,
      CODE_OSS_TAG: $build.upstream.code_oss.tag,
      CODE_OSS_COMMIT: $build.upstream.code_oss.commit,
      CODE_OSS_REPOSITORY: $build.upstream.code_oss.repository,
      CODE_OSS_VERSION: $build.runtime.code_oss_version,
      ELECTRON_VERSION: $build.runtime.electron_version,
      WRAPPER_VERSION: $build.release.wrapper_version,
      RELEASE_SET_BASE_ID: $build.release.release_set_base_id,
      RELEASE_COMPATIBILITY_STATUS: $build.release.compatibility_status,
      RELEASE_VALIDATION_ISSUE: $build.release.validation_issue,
      NODE_VERSION: $build.toolchain.node.version,
      NODE_NPM_VERSION: $build.toolchain.node.npm_version,
      NODE_ARCHIVE_URL: $build.toolchain.node.archive_url,
      NODE_ARCHIVE_SHA256: $build.toolchain.node.archive_sha256,
      PYTHON_VERSION: $build.toolchain.python_version,
      APPLE_CLANG_VERSION: $build.toolchain.apple_clang_version,
      MACOS_SDK_VERSION: $build.toolchain.macos_sdk_version
    };

def release_specification_host_config_pairs:
  (
    release_specification_host_config
    | to_entries[]
    | .key, "\u0000", .value, "\u0000"
  ),
  "__HOST_CONFIG_COMPLETE__", "\u0000", "1", "\u0000";
