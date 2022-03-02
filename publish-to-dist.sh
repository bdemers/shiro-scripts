#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1
  pwd -P
)"

DIST_PROJECT=shiro
MVN_GROUP_SLASHED="org/apache/${DIST_PROJECT}"
MVN_ARTIFACT_ID="shiro-root"
SVN_CHECKOUT_DIR="${SCRIPT_DIR}/target/svn-dist/${DIST_PROJECT}"

# env var, or first arg
RELEASE_VERSION=${RELEASE_VERSION:-${1:-}}

ARTIFACTS=()

# time stamp
ts() {
  date "+%Y-%m-%dT%H:%M:%S%z"
}

# general readiness checks
init() {
  if [ -z "${RELEASE_VERSION:-}" ]; then
    echo "[$(ts)] [ERROR] Shiro version argument required"
    exit 1
  fi
}

# validate a hash
validate() {
  local file_to_validate=${1}
  local hash_type="${2}"
  local hash_expected
  local hash_actual

  echo "[$(ts)] [INFO] validating [${file_to_validate}.${hash_type//-/}]"
  hash_expected=$(cat "${file_to_validate}.${hash_type//-/}")
  hash_actual=$(openssl "${hash_type}" -r <"${file_to_validate}" | awk '{print $1}')

  if [[ "${hash_expected}" != "${hash_actual}" ]]; then
    echo "Downloaded file: '${file_to_validate}' does not match the expected SHA1 of '${hash_actual}'"
  fi
}

# checkout the existing dist repository and create a new version directory
svn_checkout() {
  mkdir -p "${SVN_CHECKOUT_DIR}"
  echo "[$(ts)] [INFO] checking out shiro releases via svn to [${SVN_CHECKOUT_DIR}]."
  svn co https://dist.apache.org/repos/dist/release/shiro/ "${SVN_CHECKOUT_DIR}"

  if [ -e "${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}" ]; then
    echo "[$(ts)] [ERROR] Shiro version already exists: [${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}]"
    exit 2
  fi

  # create the new release version
  mkdir -p "${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}"
  cd "${SVN_CHECKOUT_DIR}" || exit 1
  svn add "${RELEASE_VERSION}"
}

download_to_svn() {
  local repo_base_url
  local curl_args

  # download the released bits
  repo_base_url="https://repository.apache.org/content/groups/public"

  # list of files to download
  ARTIFACTS=("${repo_base_url}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip"
    "${repo_base_url}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.asc")
  for hash in "md5" "sha1" "sha256" "sha512" "sha3512"; do
    ARTIFACTS+=("${repo_base_url}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.${hash}")
    ARTIFACTS+=("${repo_base_url}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.asc.${hash}")
  done

  curl_args=(
    "--silent"
    "--show-error"
    "--fail"
    "--retry" "3"
    "--retry-delay" "3"
    "--remote-name"
    "--remote-header-name"
    "--connect-timeout" "10"
    "--max-time" "60"
  )

  # Download all of them
  cd "${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}" || exit 1
  echo "[$(ts)] [INFO] downloading ${#ARTIFACTS[*]} artifacts."
  for artifact in "${ARTIFACTS[@]}"; do
    echo "[$(ts)] [INFO] downloading ${artifact}... "
    curl "${curl_args[@]}" --url "${artifact}"
  done
}

main() {
  svn_checkout

  download_to_svn

  echo "[$(ts)] [INFO] checking hashes of [${ARTIFACTS[0]}]"
  for hash in "md5" "sha1" "sha256" "sha512" "sha3-512"; do
    validate "$(basename "${ARTIFACTS[0]}")" "${hash}"
  done

  # now add them to svn
  svn add .
  svn status
  echo "[$(ts)] [INFO] You must now 'svn commit' these files from [$(dirname "${SCRIPT_DIR}")]"
}

init

main
