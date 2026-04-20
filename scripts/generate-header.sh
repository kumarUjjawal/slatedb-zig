#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
UPSTREAM_SLATEDB_DIR="${UPSTREAM_SLATEDB_DIR:-${1:-${ROOT_DIR}/../slatedb}}"
UNIFFI_DIR="${UPSTREAM_SLATEDB_DIR}/bindings/uniffi"
GO_HEADER_FILE="${UPSTREAM_SLATEDB_DIR}/bindings/go/uniffi/slatedb.h"
INCLUDE_DIR="${ROOT_DIR}/include"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/slatedb-zig-header.XXXXXX")"
TARGET_DIR="${CARGO_TARGET_DIR:-${UPSTREAM_SLATEDB_DIR}/target}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [[ ! -f "${UPSTREAM_SLATEDB_DIR}/Cargo.toml" ]]; then
  echo "missing SlateDB checkout at ${UPSTREAM_SLATEDB_DIR}" >&2
  echo "set UPSTREAM_SLATEDB_DIR or pass the path as the first argument" >&2
  exit 1
fi

cargo build --manifest-path "${UPSTREAM_SLATEDB_DIR}/Cargo.toml" -p slatedb-uniffi

mkdir -p "${INCLUDE_DIR}"

if [[ -f "${GO_HEADER_FILE}" ]]; then
  cp "${GO_HEADER_FILE}" "${INCLUDE_DIR}/slatedb.h"
  perl -0pi -e 's/[ \t]+\n/\n/g' "${INCLUDE_DIR}/slatedb.h"
  exit 0
fi

if ! command -v uniffi-bindgen-go >/dev/null 2>&1; then
  echo "uniffi-bindgen-go is required on PATH when ${GO_HEADER_FILE} is missing" >&2
  echo "install it with:" >&2
  echo "  cargo install uniffi-bindgen-go --git https://github.com/NordSecurity/uniffi-bindgen-go --tag v0.7.0+v0.31.0" >&2
  exit 1
fi

LIB_FILE=""
for candidate in \
  "${TARGET_DIR}/debug/libslatedb_uniffi.so" \
  "${TARGET_DIR}/debug/libslatedb_uniffi.dylib" \
  "${TARGET_DIR}/debug/slatedb_uniffi.dll"; do
  if [[ -f "${candidate}" ]]; then
    LIB_FILE="${candidate}"
    break
  fi
done

if [[ -z "${LIB_FILE}" ]]; then
  echo "failed to find libslatedb_uniffi under ${TARGET_DIR}/debug" >&2
  exit 1
fi

(
  cd "${UPSTREAM_SLATEDB_DIR}"
  uniffi-bindgen-go "${LIB_FILE}" \
    --library \
    --config "${UNIFFI_DIR}/uniffi.toml" \
    --out-dir "${TMP_DIR}/out"
)

GENERATED_DIR="${TMP_DIR}/out/slatedb"
GENERATED_H_FILE="$(find "${GENERATED_DIR}" -maxdepth 1 -type f -name '*.h' | head -n 1)"

if [[ -z "${GENERATED_H_FILE}" ]]; then
  echo "unexpected generator output in ${GENERATED_DIR}" >&2
  exit 1
fi

cp "${GENERATED_H_FILE}" "${INCLUDE_DIR}/slatedb.h"
perl -0pi -e 's/[ \t]+\n/\n/g' "${INCLUDE_DIR}/slatedb.h"
