#!/usr/bin/env bash

if [[ "${DBCODE_WRAPPER_DIST_CHECKPOINT_LIBRARY_LOADED:-}" == "yes" ]]; then
  return 0 2>/dev/null || exit 0
fi
DBCODE_WRAPPER_DIST_CHECKPOINT_LIBRARY_LOADED="yes"

if [[ -z "${BUILD_ROOT:-}" || -z "${DIST_ROOT:-}" ]] || ! declare -F assert_generated_path >/dev/null; then
  echo "Load host_config.sh before dist_checkpoint.sh." >&2
  return 1 2>/dev/null || exit 1
fi

DIST_CHECKPOINT_ROOT="${BUILD_ROOT}/locks"
DIST_CHECKPOINT_LOCK="${DIST_CHECKPOINT_ROOT}/dist-checkpoint.lock"
DIST_CHECKPOINT_FD="9"
DIST_CHECKPOINT_ASSEMBLY_ROOT="${BUILD_ROOT}/assembly"
DIST_CHECKPOINT_CANDIDATE="${DIST_CHECKPOINT_ASSEMBLY_ROOT}/dist.candidate"
DIST_CHECKPOINT_PREVIOUS="${DIST_CHECKPOINT_ASSEMBLY_ROOT}/dist.previous"
DIST_CHECKPOINT_ACQUISITION="none"
DIST_CHECKPOINT_STAGE=""

dist_checkpoint_prepare_root() {
  assert_generated_path "${DIST_CHECKPOINT_ROOT}"
  assert_generated_path "${DIST_CHECKPOINT_LOCK}"
  mkdir -p "${DIST_CHECKPOINT_ROOT}" || {
    echo "The dist checkpoint root could not be created: ${DIST_CHECKPOINT_ROOT}" >&2
    return 1
  }
  [[ -d "${DIST_CHECKPOINT_ROOT}" && ! -L "${DIST_CHECKPOINT_ROOT}" ]] || {
    echo "The dist checkpoint root is missing or unsafe: ${DIST_CHECKPOINT_ROOT}" >&2
    return 1
  }
  chmod 700 "${DIST_CHECKPOINT_ROOT}" || {
    echo "The dist checkpoint root permissions could not be secured." >&2
    return 1
  }

  [[ ! -L "${DIST_CHECKPOINT_LOCK}" ]] || {
    echo "The dist checkpoint lock is a symbolic link: ${DIST_CHECKPOINT_LOCK}" >&2
    return 1
  }
  : >> "${DIST_CHECKPOINT_LOCK}" || {
    echo "The dist checkpoint lock could not be created or opened." >&2
    return 1
  }
  [[ -f "${DIST_CHECKPOINT_LOCK}" && ! -L "${DIST_CHECKPOINT_LOCK}" ]] || {
    echo "The dist checkpoint lock is not a plain file: ${DIST_CHECKPOINT_LOCK}" >&2
    return 1
  }
  chmod 600 "${DIST_CHECKPOINT_LOCK}" || {
    echo "The dist checkpoint lock permissions could not be secured." >&2
    return 1
  }
}

dist_checkpoint_validate_inherited_fd() {
  local inherited_fd="${DBCODE_WRAPPER_DIST_CHECKPOINT_FD:-}"
  local lock_identity fd_identity

  [[ "${inherited_fd}" == "${DIST_CHECKPOINT_FD}" ]] || {
    echo "The inherited dist checkpoint descriptor is invalid." >&2
    return 1
  }
  [[ -e "/dev/fd/${DIST_CHECKPOINT_FD}" ]] || {
    echo "The inherited dist checkpoint descriptor is closed." >&2
    return 1
  }
  # macOS devfs reports a synthetic device number for /dev/fd, while the
  # underlying file keeps the same inode number.
  lock_identity="$(stat -f '%i' "${DIST_CHECKPOINT_LOCK}")" || return 1
  fd_identity="$(stat -f '%i' "/dev/fd/${DIST_CHECKPOINT_FD}")" || return 1
  [[ "${lock_identity}" == "${fd_identity}" ]] || {
    echo "The inherited descriptor does not identify the dist checkpoint lock." >&2
    return 1
  }
  /usr/bin/lockf -s -t 0 "${DIST_CHECKPOINT_FD}" || {
    echo "The inherited descriptor does not hold the dist checkpoint lease." >&2
    return 1
  }
}

dist_checkpoint_validate_candidate() {
  local candidate="${1:-${DIST_CHECKPOINT_CANDIDATE}}"
  [[ "${candidate}" == "${DIST_CHECKPOINT_CANDIDATE}" ]] || {
    echo "The dist checkpoint candidate is outside its fixed path: ${candidate}" >&2
    return 1
  }
  assert_generated_path "${candidate}"
  [[ -d "${candidate}" && ! -L "${candidate}" ]] || {
    echo "The dist checkpoint candidate is missing or unsafe: ${candidate}" >&2
    return 1
  }
}

dist_checkpoint_validate_previous() {
  assert_generated_path "${DIST_CHECKPOINT_PREVIOUS}"
  [[ -d "${DIST_CHECKPOINT_PREVIOUS}" && ! -L "${DIST_CHECKPOINT_PREVIOUS}" ]] || {
    echo "The previous dist checkpoint is missing or unsafe: ${DIST_CHECKPOINT_PREVIOUS}" >&2
    return 1
  }
}

dist_checkpoint_recover_promotion() {
  local has_dist="no"
  local has_candidate="no"
  local has_previous="no"

  [[ ! -L "${DIST_ROOT}" ]] || {
    echo "The dist checkpoint destination became a symbolic link: ${DIST_ROOT}" >&2
    return 1
  }
  if [[ -e "${DIST_ROOT}" ]]; then
    [[ -d "${DIST_ROOT}" ]] || {
      echo "The dist checkpoint destination is not a plain directory: ${DIST_ROOT}" >&2
      return 1
    }
    has_dist="yes"
  fi
  if [[ -e "${DIST_CHECKPOINT_CANDIDATE}" || -L "${DIST_CHECKPOINT_CANDIDATE}" ]]; then
    dist_checkpoint_validate_candidate || return 1
    has_candidate="yes"
  fi
  if [[ -e "${DIST_CHECKPOINT_PREVIOUS}" || -L "${DIST_CHECKPOINT_PREVIOUS}" ]]; then
    dist_checkpoint_validate_previous || return 1
    has_previous="yes"
  fi

  if [[ "${has_previous}" == "yes" && "${has_dist}" == "yes" && \
    "${has_candidate}" == "yes" ]]; then
    echo "The dist checkpoint promotion state is ambiguous; all checkpoints were retained." >&2
    return 1
  fi

  if [[ "${has_previous}" == "yes" && "${has_dist}" == "no" ]]; then
    mv "${DIST_CHECKPOINT_PREVIOUS}" "${DIST_ROOT}" || {
      echo "The previous complete dist checkpoint could not be restored." >&2
      return 1
    }
    has_dist="yes"
    has_previous="no"
  elif [[ "${has_previous}" == "yes" ]]; then
    rm -rf "${DIST_CHECKPOINT_PREVIOUS}" || {
      echo "The superseded dist checkpoint could not be removed." >&2
      return 1
    }
    has_previous="no"
  fi

  if [[ "${has_candidate}" == "yes" ]]; then
    rm -rf "${DIST_CHECKPOINT_CANDIDATE}" || {
      echo "The interrupted dist checkpoint candidate could not be removed." >&2
      return 1
    }
  fi
  DIST_CHECKPOINT_STAGE=""
}

dist_checkpoint_acquire() {
  local operation="${1:-host-build}"

  [[ "${operation}" =~ ^[A-Za-z0-9._-]+$ ]] || {
    echo "The dist checkpoint operation name is invalid." >&2
    return 1
  }
  dist_checkpoint_prepare_root || return 1

  if [[ -n "${DBCODE_WRAPPER_DIST_CHECKPOINT_FD:-}" ]]; then
    dist_checkpoint_validate_inherited_fd || return 1
    DIST_CHECKPOINT_ACQUISITION="borrowed"
    return 0
  fi

  exec 9>>"${DIST_CHECKPOINT_LOCK}" || {
    echo "The dist checkpoint descriptor could not be opened." >&2
    return 1
  }
  if ! /usr/bin/lockf -s -t 0 "${DIST_CHECKPOINT_FD}"; then
    exec 9>&-
    echo "Another command owns the dist checkpoint: ${DIST_CHECKPOINT_LOCK}" >&2
    return 1
  fi
  DBCODE_WRAPPER_DIST_CHECKPOINT_FD="${DIST_CHECKPOINT_FD}"
  export DBCODE_WRAPPER_DIST_CHECKPOINT_FD
  DIST_CHECKPOINT_ACQUISITION="acquired"

  if ! dist_checkpoint_recover_promotion; then
    exec 9>&-
    unset DBCODE_WRAPPER_DIST_CHECKPOINT_FD
    DIST_CHECKPOINT_ACQUISITION="none"
    return 1
  fi
}

dist_checkpoint_require_lease() {
  dist_checkpoint_prepare_root || return 1
  dist_checkpoint_validate_inherited_fd || {
    echo "This command does not hold the dist checkpoint lease." >&2
    return 1
  }
}

dist_checkpoint_create_stage() {
  dist_checkpoint_require_lease || return 1
  assert_generated_path "${DIST_CHECKPOINT_ASSEMBLY_ROOT}"
  assert_generated_path "${DIST_CHECKPOINT_CANDIDATE}"
  mkdir -p "${DIST_CHECKPOINT_ASSEMBLY_ROOT}" || {
    echo "The dist assembly root could not be created." >&2
    return 1
  }
  [[ -d "${DIST_CHECKPOINT_ASSEMBLY_ROOT}" && ! -L "${DIST_CHECKPOINT_ASSEMBLY_ROOT}" ]] || {
    echo "The dist assembly root is missing or unsafe: ${DIST_CHECKPOINT_ASSEMBLY_ROOT}" >&2
    return 1
  }
  chmod 700 "${DIST_CHECKPOINT_ASSEMBLY_ROOT}" || {
    echo "The dist assembly root permissions could not be secured." >&2
    return 1
  }
  [[ ! -e "${DIST_CHECKPOINT_CANDIDATE}" && ! -L "${DIST_CHECKPOINT_CANDIDATE}" ]] || {
    echo "A dist checkpoint candidate is already active: ${DIST_CHECKPOINT_CANDIDATE}" >&2
    return 1
  }
  mkdir "${DIST_CHECKPOINT_CANDIDATE}" || {
    echo "The dist checkpoint candidate could not be created." >&2
    return 1
  }
  DIST_CHECKPOINT_STAGE="${DIST_CHECKPOINT_CANDIDATE}"
  chmod 700 "${DIST_CHECKPOINT_STAGE}" || {
    echo "The dist checkpoint candidate permissions could not be secured." >&2
    return 1
  }
  dist_checkpoint_validate_candidate "${DIST_CHECKPOINT_STAGE}"
}

dist_checkpoint_discard_stage() {
  local candidate="${1:-${DIST_CHECKPOINT_STAGE}}"
  [[ -n "${candidate}" ]] || return 0
  dist_checkpoint_validate_candidate "${candidate}" || return 1
  rm -rf "${candidate}" || {
    echo "The dist checkpoint candidate could not be discarded." >&2
    return 1
  }
  DIST_CHECKPOINT_STAGE=""
}

dist_checkpoint_promote_stage() {
  local candidate="${1:-${DIST_CHECKPOINT_STAGE}}"

  dist_checkpoint_require_lease || return 1
  dist_checkpoint_validate_candidate "${candidate}" || return 1
  assert_generated_path "${DIST_ROOT}/checkpoint"
  assert_generated_path "${DIST_CHECKPOINT_PREVIOUS}"
  [[ ! -L "${DIST_ROOT}" ]] || {
    echo "The dist checkpoint destination is a symbolic link: ${DIST_ROOT}" >&2
    return 1
  }
  [[ ! -e "${DIST_CHECKPOINT_PREVIOUS}" && ! -L "${DIST_CHECKPOINT_PREVIOUS}" ]] || {
    echo "A previous dist checkpoint is already staged: ${DIST_CHECKPOINT_PREVIOUS}" >&2
    return 1
  }

  if [[ -e "${DIST_ROOT}" ]]; then
    [[ -d "${DIST_ROOT}" ]] || {
      echo "The existing dist checkpoint is not a plain directory: ${DIST_ROOT}" >&2
      return 1
    }
    if ! mv "${DIST_ROOT}" "${DIST_CHECKPOINT_PREVIOUS}"; then
      echo "The previous complete dist checkpoint could not be staged for promotion." >&2
      return 1
    fi
  fi

  if ! mv "${candidate}" "${DIST_ROOT}"; then
    dist_checkpoint_recover_promotion || true
    echo "The complete staged dist checkpoint could not be promoted." >&2
    return 1
  fi
  DIST_CHECKPOINT_STAGE=""

  if [[ -e "${DIST_CHECKPOINT_PREVIOUS}" ]]; then
    dist_checkpoint_validate_previous || return 1
    rm -rf "${DIST_CHECKPOINT_PREVIOUS}" || {
      echo "The previous dist checkpoint could not be removed after promotion." >&2
      return 1
    }
  fi
}

dist_checkpoint_release() {
  case "${DIST_CHECKPOINT_ACQUISITION}" in
    none|borrowed)
      return 0
      ;;
    acquired) ;;
    *)
      echo "Unknown dist checkpoint acquisition state: ${DIST_CHECKPOINT_ACQUISITION}" >&2
      return 1
      ;;
  esac

  dist_checkpoint_require_lease || return 1
  dist_checkpoint_recover_promotion || return 1
  exec 9>&- || {
    echo "The dist checkpoint descriptor could not be closed." >&2
    return 1
  }
  DIST_CHECKPOINT_ACQUISITION="none"
  unset DBCODE_WRAPPER_DIST_CHECKPOINT_FD
}

dist_checkpoint_exit() {
  local exit_status="${1:-0}"

  trap - EXIT INT TERM
  if ! dist_checkpoint_release; then
    [[ "${exit_status}" -ne 0 ]] || exit_status=1
  fi
  exit "${exit_status}"
}
