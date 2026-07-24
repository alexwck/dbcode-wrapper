#!/usr/bin/env bash

set -euo pipefail

artifact_digest() {
  local artifact_path="${1}"
  local artifact_parent
  local artifact_name

  artifact_parent="$(cd "$(dirname "${artifact_path}")" && pwd)"
  artifact_name="$(basename "${artifact_path}")"

  (
    cd "${artifact_parent}"
    {
      find "${artifact_name}" -type f -print0 |
        LC_ALL=C sort -z |
        xargs -0 shasum -a 256
      find "${artifact_name}" -type l -print0 |
        LC_ALL=C sort -z |
        while IFS= read -r -d '' artifact_item; do
          printf 'link  %s -> %s\n' "${artifact_item}" "$(readlink "${artifact_item}")"
        done
    } |
      LC_ALL=C sort |
      shasum -a 256 |
      awk '{print $1}'
  )
}

directory_content_digest() {
  local directory_path="${1}"

  (
    cd "${directory_path}"
    {
      find . -type f -print0 |
        LC_ALL=C sort -z |
        xargs -0 shasum -a 256
      find . -type l -print0 |
        LC_ALL=C sort -z |
        while IFS= read -r -d '' directory_item; do
          printf 'link  %s -> %s\n' "${directory_item}" "$(readlink "${directory_item}")"
        done
    } |
      LC_ALL=C sort |
      shasum -a 256 |
      awk '{print $1}'
  )
}
