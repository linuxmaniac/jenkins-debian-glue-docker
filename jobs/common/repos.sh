#!/bin/bash
# HEADER: managed by jenkins-job-builder, do NOT edit manually!

set -e
set -x

if [ "${GERRIT_EVENT_TYPE}" = 'patchset-created' ] ; then
  echo "*** Gerrit event type is ${GERRIT_EVENT_TYPE} ***"
  if [ -z "$ppa" ] ; then
    echo "*** Error: the ppa variable is not set. ***"
    exit 1
  elif [ "$ppa" = '${ppa}' ] || [ "$ppa" = '$ppa' ] ; then
    echo '*** Error: the ppa variable is set to ${ppa} or $ppa which corresponds to unset. ***'
    exit 1
  elif [ "$ppa" = 'none' ] ; then
    echo '*** Error: the ppa variable is set to "none". ***'
    exit 1
  else
    echo "*** Identified ppa variable ${ppa}, using for PPA repository. *** "
    PPA_REPOS="$ppa"
  fi
fi

mkdir -p binaries
for suffix in gz bz2 xz deb dsc changes ; do
  mv */*.${suffix} binaries/ || true
done

if [ -n "$PPA_REPOS" ] ; then
  export REPOS="$PPA_REPOS"
else
  if [ -n "$distribution" ] ; then
    export REPOS="internal-${distribution}"
  else
    echo "Error: distribution variable is unset, required for internal-... repository." >&2
    exit 1
  fi
fi

sudo /usr/bin/generate-reprepro-codename "${REPOS}"
export SUDO_CMD=sudo
export BASE_PATH="binaries/"
export PROVIDE_ONLY=true
export IGNORE_RELEASE_TRUNK=true
export SKIP_REMOVAL=true
/usr/bin/build-and-provide-package
