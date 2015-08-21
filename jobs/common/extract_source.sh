#!/bin/bash
# HEADER: managed by jenkins-job-builder, do NOT edit manually!

set -e

cd "${WORKSPACE}"

SOURCE_TAR="${WORKSPACE}/source.tar.gz"

if [ ! -f "${SOURCE_TAR}" ] ; then
  echo "No source found. ${SOURCE_TAR} does not exist"
  exit 1
fi

rm -rf source
if ! tar xzf "${SOURCE_TAR}" ; then
  echo "Error extracting ${SOURCE_TAR}"
  exit 1
fi

if [ ! -d source ] ; then
  echo "No source dir"
  exit 1
fi
