#!/bin/bash
# HEADER: managed by jenkins-job-builder, do NOT edit manually!
# generate apt sources sources.list and builddeps.list files

set -e

rm -f sources.list builddeps.list preferences

if ! which wget >/dev/null 2>&1 ; then
  echo "Error: no wget found" >&2
  exit 1
fi

WGET_OPTS="--quiet --tries=3 --timeout=5 -O /dev/null"
WGET="$(which wget) ${WGET_OPTS}"
DEB_MIRROR="https://debian.sipwise.com"
DEB_OUR="https://deb.sipwise.com"
DEB_DEV="https://jenkins.mgm.sipwise.com"

config_yml_support() {
  # only releases >=mr3.3 use the config.yml approach instead of using wheezy-backports
  case ${short_release} in
    2.8*|3.0*|3.1*|mr3.2*)
      echo "*** release ${release} needs backports ***"
      return 1
      ;;
    *)
      echo "*** release ${release} doesn't need backports ***"
      return 0
      ;;
  esac
}

builddeps_support() {
  case ${short_release} in
    2.8*|3.0*|3.1*|mr3.[2-6]*|mr3.7.1)
      echo "*** release ${release} needs builddeps ***"
      return 0
      ;;
    *)
      echo "*** release ${release} doesn't need builddeps ***"
      return 1
      ;;
  esac
}

trunk_builds() {
  if [ -z "${release}" ] ; then
    echo "Error: release is unset" >&2
    exit 1
  fi

  cat << EOF >> builddeps.list
deb ${DEB_OUR}/autobuild/ ${release} main
EOF
}

sources() {
  local components

  if [ -z "${distribution}" ] ; then
    echo "Error: distribution is unset" >&2
    exit 1
  fi

  case "${distribution}" in
    squeeze) components="main contrib non-free" ;;
    *) components="main"
  esac

  cat << EOF >> sources.list
deb ${DEB_MIRROR}/debian/ ${distribution} ${components}
EOF

  case "${distribution}" in
    squeeze)
      cat << EOF >> sources.list
deb ${DEB_MIRROR}/debian/ ${distribution}-updates ${components}
deb ${DEB_MIRROR}/debian/ ${distribution}-lts main
deb ${DEB_OUR}/percona/ ${distribution} main
EOF
      ;;
  esac

  cat << EOF >> sources.list
deb ${DEB_MIRROR}/debian-security/ ${distribution}-security ${components}
EOF
}

add_repo() {
  local rel=$1
  local dist=$2
  local release_file="${DEB_OUR}/autobuild/release/${rel}/dists/${dist}/Release"

  if ${WGET} "${release_file}" ; then
    echo "*** Repository ${release_file} seems to be available. ***"
    cat << EOF >> builddeps.list
deb ${DEB_OUR}/autobuild/release/${rel}/ ${dist} main
EOF
  else
    echo "*** Warning: could not access ${release_file} - skipping repository. ***"
  fi
}

add_private_release() {
  if [[ "${release}" =~ release-trunk ]] ; then
    return
  fi

  if [[ "${release}" =~ release-.+-update ]] ; then
    echo "*** ${release} detected. Adding release-${short_release} too ***"
    add_repo "release-${short_release}" "release-${short_release}"
  fi
  add_repo "${release}" "${release}"
}

release() {
  if [ -z "${release}" ] ; then
    echo "Error: release is unset" >&2
    exit 1
  fi

  if [ "${release}" = none ] || [ "${release}" = "\$release" ] ; then
    case "${branch}" in
      2.8|mr[0-9]*)
        release="release-${branch}-update"
        echo "*** Release environment var [\${release}] is either 'none' or '\${release}' but branch is matching release schema, assuming release ${release} ***"
        ;;
      *)
        echo "*** Release environment var [${release}] is either 'none' or '\${release}' and branch not matching mr[0-9]*, enabling trunk repos setup ***"
        release="release-trunk-${distribution}"
        ;;
    esac
  fi

  if [[ ${release} =~ ^release-trunk-* ]] ; then
    echo "*** Release environment var ${release}, enabling trunk repos setup ***"
    trunk_builds
  fi

  short_release=${release%%-update}
  short_release=${short_release##release-}

  add_private_release

  if builddeps_support ; then
    echo "*** Release ${release} needs builddeps. Adding release-${short_release}-builddeps ***"
    cat << EOF >> builddeps.list
deb ${DEB_OUR}/autobuild/release/release-${short_release}-builddeps release-${short_release}-builddeps main
EOF
  fi

  if ! config_yml_support ; then
    local base
    echo "*** Release ${release} doesn't support config.yml approach. Adding ${distribution}-backports ***"
    case "${short_release}" in
      2.8) base="squeeze-backports" ;;
      *)   base="debian" ;;
    esac
    cat << EOF >> builddeps.list
deb ${DEB_OUR}/${base} ${distribution}-backports main
EOF
  fi
}

preferences() {
  cat << EOF >> preferences
// begin of builddeps pinning
Package: *
Pin: origin deb.sipwise.com
Pin-Priority: 990
// end of builddeps pinning

// begin of builddeps pinning
Package: *
Pin: origin debian.sipwise.com
Pin-Priority: 500
// end of builddeps pinning

EOF
}

gerrit_build() {
  if [ -z "$ppa" ] || [ "$ppa" = none ] ; then
    echo "Error: ppa is unset" >&2
    exit 1
  fi
  cat << EOF >> builddeps.list
deb ${DEB_DEV}/debian/ ${ppa} main
EOF

  cat > preferences << EOF
// begin of builddeps pinning
Package: *
Pin: origin ${DEB_DEV##https://}
Pin-Priority: 991
// end of builddeps pinning

EOF
}

gerrit_release() {
  if [ -z "${GERRIT_BRANCH}" ] ; then
    echo "Error: Gerrit branch [GERRIT_BRANCH] is unset" >&2
    exit 1
  fi

  case ${GERRIT_BRANCH} in
    master|mr[0-9]*|2.8) branch="${GERRIT_BRANCH}";;
    *) branch=master;;
  esac
}

rm -f ./*.list || true

if [ "${GERRIT_EVENT_TYPE}" = 'patchset-created' ] ; then
  echo "*** Gerrit event type is ${GERRIT_EVENT_TYPE} ***"
  gerrit_build
  gerrit_release
elif [ "${GERRIT_EVENT_TYPE}" = 'change-merged' ] ; then
  echo "*** Gerrit event type is ${GERRIT_EVENT_TYPE} ***"
  gerrit_release
else
  echo "*** No gerrit detected ***"
fi

sources
release
preferences
