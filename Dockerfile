FROM jenkins

MAINTAINER Victor Seva <linuxmaniac@torreviejawireless.org>

USER root

RUN apt-get update && apt-get install -y git-buildpackage cowbuilder pristine-tar && rm -rf /var/lib/apt/lists/*

COPY jenkins_sudo /etc/sudoers.d/jenkins
RUN chmod 440 /etc/sudoers.d/jenkins

RUN mkdir -p /srv/repository/ 
RUN chown -R jenkins /srv/repository

USER jenkins

COPY plugins.txt /plugins.txt
RUN /usr/local/bin/plugins.sh /plugins.txt
