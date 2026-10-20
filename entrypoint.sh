#!/usr/bin/env bash

set -euo pipefail

export GITHUB="true"

GITHUB_ACTION_PATH="${GITHUB_ACTION_PATH%/}"
DRONE_SCP_RELEASE_URL="${DRONE_SCP_RELEASE_URL:-https://github.com/appleboy/drone-scp/releases/download}"
DRONE_SCP_VERSION="${DRONE_SCP_VERSION:-1.8.0}"
DRONE_SCP_BINARY="${DRONE_SCP_BINARY:-/usr/local/bin/drone-scp}"

function log_error() {
  echo "$1" >&2
  exit "$2"
}

function detect_client_info() {
  CLIENT_PLATFORM="${SCP_CLIENT_OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
  CLIENT_ARCH="${SCP_CLIENT_ARCH:-$(uname -m)}"

  case "${CLIENT_PLATFORM}" in
  darwin | linux | windows) ;;
  *) log_error "Unknown or unsupported platform: ${CLIENT_PLATFORM}. Supported platforms are Linux, Darwin, and Windows." 2 ;;
  esac

  case "${CLIENT_ARCH}" in
  x86_64* | i?86_64* | amd64*) CLIENT_ARCH="amd64" ;;
  aarch64* | arm64*) CLIENT_ARCH="arm64" ;;
  *) log_error "Unknown or unsupported architecture: ${CLIENT_ARCH}. Supported architectures are x86_64, i686, and arm64." 3 ;;
  esac
}

detect_client_info
DOWNLOAD_URL_PREFIX="${DRONE_SCP_RELEASE_URL}/v${DRONE_SCP_VERSION}"
CLIENT_BINARY="drone-scp-${DRONE_SCP_VERSION}-${CLIENT_PLATFORM}-${CLIENT_ARCH}"
TARGET="${DRONE_SCP_BINARY}"
INSECURE_OPTION=""
if [[ "${INPUT_CURL_INSECURE}" == 'true' ]]; then
  INSECURE_OPTION="--insecure"
fi

# Reuse the existing binary only when it reports the requested version,
# since the shared install path no longer encodes the version in its name.
if [[ -x "${TARGET}" ]] && "${TARGET}" --version 2>/dev/null | grep -q "${DRONE_SCP_VERSION}"; then
  echo "Binary ${TARGET} already exists with version ${DRONE_SCP_VERSION}, skipping download."
else
  echo "Downloading ${CLIENT_BINARY} from ${DOWNLOAD_URL_PREFIX}"
  mkdir -p "$(dirname "${TARGET}")"
  curl -fsSL --retry 5 --keepalive-time 2 ${INSECURE_OPTION} "${DOWNLOAD_URL_PREFIX}/${CLIENT_BINARY}" -o "${TARGET}"
  chmod +x "${TARGET}"
fi

echo "======= CLI Version Information ======="
"${TARGET}" --version
echo "======================================="
if [[ "${INPUT_CAPTURE_STDOUT}" == 'true' ]]; then
  {
    echo 'stdout<<EOF'
    "${TARGET}" "$@" | tee -a "${GITHUB_OUTPUT}"
    echo 'EOF'
  } >>"${GITHUB_OUTPUT}"
else
  "${TARGET}" "$@"
fi
