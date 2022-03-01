#!/bin/bash

DIST_PROJECT=shiro
MVN_GROUP_SLASHED="org/apache/${DIST_PROJECT}"
MVN_ARTIFACT_ID="shiro-root"
SVN_CHECKOUT_DIR="./target/svn-dist/${DIST_PROJECT}"

# env var, or first arg
RELEASE_VERSION=${RELEASE_VERSION:-$1}
RELEASE_VERSION=${RELEASE_VERSION:-"VERSION_MISSING"}

# validate a hash
validate() {
  local file_to_validate=${1}
  local hash_type="${2}"
  local hash_expected
  local hash_actual

  hash_expected=$(cat "${file_to_validate}.${hash_type//-}")
  hash_actual=$(openssl "${hash_type}" -r < "${file_to_validate}" | awk '{print $1}')

  if [[ "${hash_expected}" != "${hash_actual}" ]]; then
    echo "Downloaded file: '${file_to_validate}' does not match the expected SHA1 of '${hash_actual}'"
  fi
}

mkdir -p "${SVN_CHECKOUT_DIR}"
svn co https://dist.apache.org/repos/dist/release/shiro/ "${SVN_CHECKOUT_DIR}"

# create the new release version
mkdir -p "${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}"
svn add "${RELEASE_VERSION}"
cd "${SVN_CHECKOUT_DIR}/${RELEASE_VERSION}"

# download the released bits
REPO_BASE_URL="https://repository.apache.org/content/groups/public"

# list of files to download
ARTIFACTS=("${REPO_BASE_URL}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip" \
           "${REPO_BASE_URL}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.md5" \
           "${REPO_BASE_URL}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.sha1" \
           "${REPO_BASE_URL}/${MVN_GROUP_SLASHED}/${MVN_ARTIFACT_ID}/${RELEASE_VERSION}/${MVN_ARTIFACT_ID}-${RELEASE_VERSION}-source-release.zip.asc" )

CURL_CMD="curl -C - -O"

# Download all of them
for ii in "${ARTIFACTS[@]}"
do
    ${CURL_CMD} $ii
done

# only the main artifact has a .sha1
for hash in "md5" "sha1" "sha512" "sha3-512"; do
  validate "$(basename "${ARTIFACTS[0]}")" "${hash}"
done

# now add them to svn
svn add .
svn status
echo "You must now 'svn commit' these files from $(dirname $PWD)"
