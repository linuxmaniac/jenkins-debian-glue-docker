#!/bin/bash
ACTION="${1:-run}"

case $ACTION in
  build)
    docker build --tag linuxmaniac/jenkins-debian-glue-docker:latest .
  ;;
  run)
    docker run -i --privileged --rm=true --name jdg -p 8080:8080 -p 50000:50000 \
      -v "${HOME}"/Projects/jdg_home:/var/jenkins_home:rw \
      -v "${HOME}"/Projects/jdg_pbuilder:/var/cache/pbuilder/:rw \
      -v "${HOME}"/Projects/jdg_repository:/var/repository/:rw \
      linuxmaniac/jenkins-debian-glue-docker
  ;;
esac

