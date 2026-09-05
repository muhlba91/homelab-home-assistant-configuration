#!/bin/bash
# util.sh — shared helper functions for lifecycle scripts.
# Source this file; do not execute it directly.

# Compute the SHA-256 digest of a single file.
# Args:    $1 file — path to the file
# Returns: hex digest string (stdout)
function _sha256() {
  sha256sum "${1}" | awk '{print $1}'
}

# Compute a stable SHA-256 digest of an entire directory tree.
# Hashes all files sorted by path for filesystem-order independence.
# Args:    $1 dir — root directory to hash
# Returns: hex digest string (stdout)
function _sha256_dir() {
  local dir="${1}"
  find "${dir}" -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}'
}

# Check whether a named digest differs from the previously saved one.
# Args:    $1 state_dir    — directory holding <name>.sha256 state files
#          $2 name         — identifier for the state file
#          $3 current_hash — digest to compare against stored value
# Returns: 0 if changed or no prior state; 1 if unchanged
function _has_changed() {
  local state_dir="${1}"
  local name="${2}"
  local current_hash="${3}"
  local state_file="${state_dir}/${name}.sha256"

  if [ ! -f "${state_file}" ]; then
    return 0  # no prior state → treat as changed
  fi

  local stored_hash
  stored_hash=$(cat "${state_file}")
  [ "${current_hash}" != "${stored_hash}" ]
}

# Persist a digest to the state directory for future comparisons.
# Args:    $1 state_dir — directory to write the state file into
#          $2 name      — identifier; written as <name>.sha256
#          $3 hash      — hex digest to store
function _save_hash() {
  local state_dir="${1}"
  local name="${2}"
  local hash="${3}"
  echo "${hash}" > "${state_dir}/${name}.sha256"
}
