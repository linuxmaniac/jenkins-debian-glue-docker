FROM jenkins

MAINTAINER Victor Seva <linuxmaniac@torreviejawireless.org>

USER root

COPY jdg.list /etc/apt/sources.list.d/jdg.list

RUN wget -O - http://jenkins.grml.org/debian/C525F56752D4A654.asc | apt-key add -

RUN apt-get update && apt-get install -y \
	jenkins-debian-glue-buildenv-git \
	jenkins-debian-glue-buildenv-piuparts \
	jenkins-debian-glue-buildenv-slave \
	jenkins-debian-glue-buildenv-taptools \
	jenkins-debian-glue-buildenv-lintian \
	jenkins-job-builder && \
	rm -rf /var/lib/apt/lists/*

COPY jenkins_sudo /etc/sudoers.d/jenkins
RUN chmod 440 /etc/sudoers.d/jenkins

# root of repositories as volumen so it
# can be persisted and survive image upgrades
VOLUME /srv/repository
RUN chown -R jenkins /srv/repository

USER jenkins

COPY plugins.txt /plugins.txt
RUN /usr/local/bin/plugins.sh /plugins.txt
