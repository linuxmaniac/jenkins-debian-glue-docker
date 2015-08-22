#!/bin/bash
ACTION="${1:-run}"
BASE_DIR="${HOME}/Projects"
JDB_TAG=linuxmaniac/jenkins-debian-glue-docker
JDB_NAME=jdb
JDB_PORT=8080
JDB_SLAVE_PORT=50000

# volume dirs
for dir in jdg_home jdg_pbuilder jdg_repository ; do
  mkdir -p "${BASE_DIR}/${dir}"
done

case ${ACTION} in
  build)
    docker build --tag ${JDB_TAG}:latest .
  ;;
  run)
    docker run -i --privileged --rm=true --name="${JDB_NAME}" \
      -p ${JDB_PORT}:8080 \
      -p ${JDB_SLAVE_PORT}:50000 \
      -v "${BASE_DIR}"/jdg_home:/var/jenkins_home:rw \
      -v "${BASE_DIR}"/jdg_pbuilder:/var/cache/pbuilder/:rw \
      -v "${BASE_DIR}"/jdg_repository:/var/repository/:rw "${JDB_TAG}"
  ;;
  *)
    echo "unknown action ${ACTION}"
    exit 1
esac

