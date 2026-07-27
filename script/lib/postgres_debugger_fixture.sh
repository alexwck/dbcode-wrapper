#!/usr/bin/env bash

postgres_debugger_fixture_root="${REPO_ROOT}/host/proof/postgres-debugger"
postgres_debugger_containerfile="${postgres_debugger_fixture_root}/Containerfile"
postgres_debugger_seed_sql="${postgres_debugger_fixture_root}/seed.sql"
postgres_debugger_proof_sql="${postgres_debugger_fixture_root}/postgres-debugger-proof.sql"
postgres_debugger_container="dbcode-wrapper-proof-postgres-debugger"
postgres_debugger_image="localhost/dbcode-wrapper-postgres-debugger:17.4-pldebugger-1.10"
postgres_debugger_base_image="docker.io/library/postgres:17.4-bookworm@sha256:304ab813518754228f9f792f79d6da36359b82d8ecf418096c636725f8c930ad"
postgres_debugger_package="postgresql-17-pldebugger=1:1.10-1.pgdg12+1"
postgres_debugger_port="55434"
postgres_debugger_database="dbcode_debugger_proof"
postgres_debugger_admin_role="dbcode_debugger_admin"
postgres_debugger_owner_role="dbcode_debugger"
postgres_debugger_fixture_summary='{}'

postgres_debugger_fixture_file_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

postgres_debugger_fixture_image_id() {
  podman image inspect "${postgres_debugger_image}" |
    jq -er '.[0].Id'
}

postgres_debugger_fixture_normalized_image_id() {
  local image_id
  image_id="$(postgres_debugger_fixture_image_id)"
  case "${image_id}" in
    sha256:*) printf '%s\n' "${image_id}" ;;
    *) printf 'sha256:%s\n' "${image_id}" ;;
  esac
}

postgres_debugger_fixture_image_contract() {
  podman image inspect "${postgres_debugger_image}" |
    jq -r '.[0].Labels["io.dbcode-wrapper.fixture.containerfile-sha256"] // ""'
}

postgres_debugger_fixture_prepare_image() {
  local expected_contract
  local current_contract=""
  expected_contract="$(postgres_debugger_fixture_file_sha256 "${postgres_debugger_containerfile}")"

  if podman image exists "${postgres_debugger_image}"; then
    current_contract="$(postgres_debugger_fixture_image_contract)"
  fi

  if [[ "${current_contract}" != "${expected_contract}" ]]; then
    podman build \
      --pull=missing \
      --build-arg "DBCODE_WRAPPER_FIXTURE_CONTAINERFILE_SHA256=${expected_contract}" \
      --tag "${postgres_debugger_image}" \
      "${postgres_debugger_fixture_root}" >&2
  fi

  [[ "$(postgres_debugger_fixture_image_contract)" == "${expected_contract}" ]] || {
    echo "The PostgreSQL debugger fixture image does not match its Containerfile." >&2
    return 1
  }
}

postgres_debugger_fixture_assert_container() {
  local expected_image_id="$1"
  local expected_contract="$2"
  local container_json
  container_json="$(podman inspect "${postgres_debugger_container}")"

  jq -e \
    --arg expected_image_id "${expected_image_id}" \
    --arg expected_contract "${expected_contract}" \
    --arg expected_port "${postgres_debugger_port}" \
    --arg expected_database "${postgres_debugger_database}" \
    --arg expected_admin_role "${postgres_debugger_admin_role}" '
      .[0].Image == $expected_image_id
      and .[0].Config.Labels["io.dbcode-wrapper.fixture.id"] == "postgres-debugger"
      and .[0].Config.Labels["io.dbcode-wrapper.fixture.containerfile-sha256"] == $expected_contract
      and .[0].Config.Cmd == ["-c", "shared_preload_libraries=plugin_debugger"]
      and any(.[0].Config.Env[];
        . == "POSTGRES_HOST_AUTH_METHOD=trust")
      and any(.[0].Config.Env[];
        . == ("POSTGRES_DB=" + $expected_database))
      and any(.[0].Config.Env[];
        . == ("POSTGRES_USER=" + $expected_admin_role))
      and .[0].HostConfig.PortBindings["5432/tcp"] == [
        {HostIp: "127.0.0.1", HostPort: $expected_port}
      ]
    ' <<<"${container_json}" >/dev/null || {
      echo "The existing PostgreSQL debugger fixture container belongs to a different fixture build." >&2
      echo "Review that exact container before replacing it: ${postgres_debugger_container}" >&2
      return 1
    }
}

postgres_debugger_fixture_prepare_container() {
  local expected_image_id
  local expected_contract
  expected_image_id="$(postgres_debugger_fixture_image_id)"
  expected_contract="$(postgres_debugger_fixture_file_sha256 "${postgres_debugger_containerfile}")"

  if ! podman container exists "${postgres_debugger_container}"; then
    podman run --detach \
      --name "${postgres_debugger_container}" \
      --label "io.dbcode-wrapper.fixture.id=postgres-debugger" \
      --label "io.dbcode-wrapper.fixture.containerfile-sha256=${expected_contract}" \
      --env "POSTGRES_USER=${postgres_debugger_admin_role}" \
      --env "POSTGRES_DB=${postgres_debugger_database}" \
      --env POSTGRES_HOST_AUTH_METHOD=trust \
      --publish "127.0.0.1:${postgres_debugger_port}:5432" \
      "${postgres_debugger_image}" \
      -c shared_preload_libraries=plugin_debugger >/dev/null
  else
    postgres_debugger_fixture_assert_container "${expected_image_id}" "${expected_contract}"
    if [[ "$(podman inspect --format '{{.State.Running}}' "${postgres_debugger_container}")" != "true" ]]; then
      podman start "${postgres_debugger_container}" >/dev/null
    fi
  fi
}

postgres_debugger_fixture_wait_until_ready() {
  local stable_ready_checks=0
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if podman exec "${postgres_debugger_container}" \
      pg_isready -U "${postgres_debugger_admin_role}" -d "${postgres_debugger_database}" >/dev/null 2>&1; then
      stable_ready_checks=$((stable_ready_checks + 1))
      if [[ ${stable_ready_checks} -ge 3 ]]; then
        return 0
      fi
    else
      stable_ready_checks=0
    fi
    sleep 1
  done

  echo "The PostgreSQL debugger fixture did not become ready." >&2
  return 1
}

postgres_debugger_fixture_seed() {
  local seeded="no"
  local attempt
  for attempt in 1 2 3 4 5; do
    if podman exec -i "${postgres_debugger_container}" \
      psql -U "${postgres_debugger_admin_role}" -d "${postgres_debugger_database}" \
      < "${postgres_debugger_seed_sql}" >/dev/null; then
      seeded="yes"
      break
    fi
    sleep 1
  done

  [[ "${seeded}" == "yes" ]] || {
    echo "The PostgreSQL debugger fixture could not be seeded." >&2
    return 1
  }
}

postgres_debugger_fixture_verify() {
  local verification
  local shared_preload_libraries
  local extension_version
  local routine_language
  local routine_owner
  local routine_owner_is_superuser
  local expected_result
  local owner_result

  verification="$(
    podman exec "${postgres_debugger_container}" \
      psql -At -F '|' \
      -U "${postgres_debugger_admin_role}" \
      -d "${postgres_debugger_database}" \
      -c "
        SELECT
          current_setting('shared_preload_libraries'),
          extension.extversion,
          language.lanname,
          owner.rolname,
          owner.rolsuper,
          debugger_proof.calculate_total(5, 3)
        FROM pg_extension AS extension
        CROSS JOIN pg_proc AS routine
        JOIN pg_language AS language ON language.oid = routine.prolang
        JOIN pg_roles AS owner ON owner.oid = routine.proowner
        WHERE extension.extname = 'pldbgapi'
          AND routine.oid = 'debugger_proof.calculate_total(integer,integer)'::regprocedure;
      "
  )"
  IFS='|' read -r \
    shared_preload_libraries \
    extension_version \
    routine_language \
    routine_owner \
    routine_owner_is_superuser \
    expected_result <<<"${verification}"

  owner_result="$(
    podman exec "${postgres_debugger_container}" \
      psql -h 127.0.0.1 -At \
      -U "${postgres_debugger_owner_role}" \
      -d "${postgres_debugger_database}" \
      -c 'SELECT debugger_proof.calculate_total(5, 3);'
  )"

  case ",${shared_preload_libraries// /}," in
    *,plugin_debugger,*) ;;
    *)
      echo "PostgreSQL did not preload plugin_debugger." >&2
      return 1
      ;;
  esac
  [[ "${extension_version}" == "1.1" ]] || {
    echo "PostgreSQL did not install the expected pldbgapi 1.1 extension." >&2
    return 1
  }
  [[ "${routine_language}" == "plpgsql" ]] || {
    echo "The debugger proof routine is not PL/pgSQL." >&2
    return 1
  }
  [[ "${routine_owner}" == "${postgres_debugger_owner_role}" ]] || {
    echo "The debugger proof role does not own the routine." >&2
    return 1
  }
  [[ "${routine_owner_is_superuser}" == "f" ]] || {
    echo "The debugger proof role must remain a non-superuser routine owner." >&2
    return 1
  }
  [[ "${expected_result}" == "22" && "${owner_result}" == "22" ]] || {
    echo "The debugger proof routine returned an unexpected result." >&2
    return 1
  }

  local image_id
  local containerfile_sha256
  local seed_sha256
  image_id="$(postgres_debugger_fixture_normalized_image_id)"
  containerfile_sha256="$(postgres_debugger_fixture_file_sha256 "${postgres_debugger_containerfile}")"
  seed_sha256="$(postgres_debugger_fixture_file_sha256 "${postgres_debugger_seed_sql}")"

  postgres_debugger_fixture_summary="$(
    jq -cn \
      --arg address "127.0.0.1:${postgres_debugger_port}/${postgres_debugger_database}" \
      --arg image "${postgres_debugger_image}@${image_id}" \
      --arg base_image "${postgres_debugger_base_image}" \
      --arg package "${postgres_debugger_package}" \
      --arg containerfile_sha256 "${containerfile_sha256}" \
      --arg seed_sha256 "${seed_sha256}" \
      --arg shared_preload_libraries "${shared_preload_libraries}" \
      --arg extension_version "${extension_version}" \
      --arg routine_owner "${routine_owner}" \
      --arg expected_result "${expected_result}" '
        {
          address: $address,
          image: $image,
          base_image: $base_image,
          package: $package,
          containerfile_sha256: $containerfile_sha256,
          seed_sha256: $seed_sha256,
          server_enforced_loopback: true,
          authentication: "local-loopback-test-fixture",
          shared_preload_libraries: $shared_preload_libraries,
          extension: {name: "pldbgapi", version: $extension_version},
          routine: {
            schema: "debugger_proof",
            name: "calculate_total",
            language: "plpgsql",
            owner: $routine_owner,
            owner_is_superuser: false,
            arguments: [5, 3],
            expected_result: ($expected_result | tonumber)
          }
        }
      '
  )"
}

postgres_debugger_fixture_prepare() {
  local workspace_root="$1"
  require_command podman
  require_command jq
  [[ -d "${workspace_root}" && ! -L "${workspace_root}" ]] || {
    echo "The debugger proof workspace must be an existing real directory." >&2
    return 1
  }

  postgres_debugger_fixture_prepare_image
  postgres_debugger_fixture_prepare_container
  postgres_debugger_fixture_wait_until_ready
  postgres_debugger_fixture_seed
  postgres_debugger_fixture_verify
  cp "${postgres_debugger_proof_sql}" "${workspace_root}/postgres-debugger-proof.sql"
}
