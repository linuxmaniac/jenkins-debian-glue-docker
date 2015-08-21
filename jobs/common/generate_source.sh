#!/bin/bash
# HEADER: managed by jenkins-job-builder, do NOT edit manually!

set -e

check_uuid_parameter() {
  if [ -z "${uuid}" ] ; then
    echo "uuid=$(uuidgen)"
  else
    echo "uuid=${uuid}"
  fi
}

bypass_git_parameters () {
  local _vars=$(compgen -A variable | grep GIT_)
  for _var in $_vars ; do
    echo $_var=${!_var}
  done
}

cd source

if [ -n "${GERRIT_PATCHSET_REVISION:-}" ] ; then
    random_branch="jenkins-build-$$"

    echo "*** We seem to be building for Gerrit ***"

    echo "Making sure that random_branch $random_branch does not exist"
    git branch -D "$random_branch" || true

    echo "*** Fetching Gerrit patchsets/commits from ${GIT_URL} ***"
    git fetch --tags --progress ${GIT_URL} +refs/changes/*:refs/remotes/origin/*

    echo "Checking out branch $random_branch based on Gerrit patchset revision ${GERRIT_PATCHSET_REVISION} ***"
    git checkout -b "$random_branch" "$GERRIT_PATCHSET_REVISION"
else
  dest_branch="$branch"
  if [ "$tag" != none ] ; then
    dest_branch="$tag"
  fi
  echo "Making sure that dest_branch $dest_branch does not exist"
  git branch -D "$dest_branch" || true
  if [ -n "${GIT_FALLBACK_BRANCH}" ] ; then
    echo "*** GIT_FALLBACK_BRANCH is set - falling back to branch $GIT_FALLBACK_BRANCH ***"
    git checkout "${dest_branch}" || { git branch -D "$GIT_FALLBACK_BRANCH" || true ; git checkout "${GIT_FALLBACK_BRANCH}" && GIT_FALLBACK_USED=true ; }
  else
    git checkout "${dest_branch}"
  fi
fi

cd "${WORKSPACE}"
tar czf "${WORKSPACE}"/source.tar.gz source

# export GIT_* vars
bypass_git_parameters > "${WORKSPACE}"/git.prop

# check uuid parameter
check_uuid_parameter >> "${WORKSPACE}"/git.prop

# PROJECTNAME
echo "PROJECTNAME=${PROJECTNAME}" >> "${WORKSPACE}"/git.prop

if [ "${GIT_FALLBACK_USED}" = "true" ] ; then
  USER_REPO="${PROJECTNAME}_${branch//\//_}"
  echo "*** setting PPA_REPOS from branch ${USER_REPO} ***"
  echo "ppa=${USER_REPO}" >> "${WORKSPACE}"/git.prop
  echo "branch=${GIT_FALLBACK_BRANCH}" >> "${WORKSPACE}"/git.prop
fi

if [ -r "${WORKSPACE}"/git.prop ] ; then
  echo "*** Displaying property git.prop as reference: ***"
  cat "${WORKSPACE}"/git.prop
  echo "*** End of ${WORKSPACE}/git.prop ***"
fi
