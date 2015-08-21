#!/bin/bash
# HEADER: managed by jenkins-job-builder, do NOT edit manually!

set -e

registry="docker1.mgm.sipwise.com:443"

if [ "$(hostname --fqdn)" != "jenkins-dev.mgm.sipwise.com" ] ; then
  echo "*** Skipping. Only for jenkins-dev.mgm.sipwise.com for now! ***"
  exit 0
fi

create_dockerfile() {
  local product="$1"
  local image="$2"
  mkdir "${product}"

  echo "*** Generating ${product}/Dockerfile based on sipwise/${image} ***"
  cat > "${product}/Dockerfile" <<EOF
FROM ${registry}/sipwise/${image}:latest
USER root

# we don't want to skip any further steps because of existing caches
ENV REFRESHED_AT $(date +%Y-%m-%d)_${BUILD_NUMBER}

# make sure ngcp-ppa is available
RUN apt-get update && apt-get --yes install ngcp-dev-tools
RUN ngcp-ppa --clean --force --skip-search ${ppa}

# avoid service startups during update
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
    && echo 'exit 101' >> /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# update system
RUN FORCE="yes" ngcp-update

# make sure services are set up for supervisord usage
RUN ngcp-toggle-daemonize-config --disable-daemonize
RUN ngcpcfg build

# explicitely set password of sipwise user
RUN echo sipwise:sipwise | chpasswd

# install supervisor
RUN apt-get --yes install supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# get rid of possibly stale files (yes, we need a better solution for this, see gerrit #1757)
RUN find /var/run/ -name \*.pid | xargs rm -f

# get rid of service startup blocker again
RUN rm -f /usr/sbin/policy-rc.d

# ssh
EXPOSE 22
# www_csc
EXPOSE 443
# www_admin
EXPOSE 1443
# ossbss
EXPOSE 2443
# xcap
EXPOSE 1080
# sip [tcp+udp]
EXPOSE 5060
# sip [TLS]
EXPOSE 5061

CMD ["/usr/bin/supervisord"]
EOF
}

create_supervisorfile() {
  local product="$1"

  cat > "${product}/supervisord.conf" <<EOF
[supervisord]
nodaemon=true

[group:web]
programs=ngcp-panel,nginx

[group:db]
programs=mysql,redis

[group:sip]
programs=asterisk,kamailio_lb,kamailio_proxy,mediator,prosody,rateomat,rtpengine,sems

[group:system]
programs=rsyslogd,sshd

[program:asterisk]
command=/usr/sbin/asterisk -n -f

[program:kamailio_lb]
command=/usr/sbin/kamailio -f /etc/kamailio/lb/kamailio.cfg -P /var/run/kamailio/kamailio.lb.pid -m 125 -M 16 -u kamailio -g kamailio -D

[program:kamailio_proxy]
command=/usr/sbin/kamailio -f /etc/kamailio/proxy/kamailio.cfg -P /var/run/kamailio/kamailio.proxy.pid -m 125 -M 32 -u kamailio -g kamailio -D

[program:mediator]
command=/bin/bash -c "source /etc/init.d/mediator start"

[program:mysql]
command=/usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --user=mysql --log-error=/var/log/mysql/mysqld.err --pid-file=/var/run/mysqld/mysqld.pid --socket=/var/run/mysqld/mysqld.sock --port=3306

[program:ngcp-panel]
directory=/usr/share/ngcp-panel
user=www-data
command=/usr/share/ngcp-panel/ngcp_panel_fastcgi.pl --listen /var/run/fastcgi/ngcp-panel.sock --daemon --pidfile /var/run/fastcgi/ngcp-panel.pid --nproc 10

[program:nginx]
command=/usr/sbin/nginx
stdout_events_enabled=true
stderr_events_enabled=true

[program:prosody]
command=/bin/bash -c "source /etc/init.d/prosody start"

[program:rateomat]
command=/bin/bash -c "source /etc/default/ngcp-rate-o-mat && exec /usr/sbin/rate-o-mat"

[program:redis]
command=/usr/bin/redis-server /etc/redis/redis.conf

[program:rsyslogd]
command=/usr/sbin/rsyslogd -n

[program:rtpengine]
command=bash -c "source /etc/init.d/ngcp-rtpengine-daemon start"

[program:sems]
command=/usr/sbin/ngcp-sems -P /var/run/ngcp-sems/ngcp-sems.pid -u sems -g sems -f /etc/ngcp-sems/sems.conf -E

[program:sshd]
command=/usr/sbin/sshd -D
autorestart=true

## fails, investigate?
#[program:collectd]
#command=/usr/sbin/collectd -C /etc/collectd/collectd.conf -f
#[program:collectdmon]
#command=/usr/sbin/collectdmon -P /var/run/collectdmon.pid -- -C /etc/collectd/collectd.conf

## ignore?
# /usr/sbin/rsyslogd
# /usr/sbin/cron
# /usr/sbin/exim4 -bd -q30m
# /usr/sbin/ntpd -p /var/run/ntpd.pid -g -c /var/lib/ntp/ntp.conf.dhcp -u 105:107
EOF
}

pull_docker() {
  local image="$1"
  echo "*** Running docker pull ${image}:latest ***"
  docker pull "${registry}/sipwise/${image}:latest"
}

build_docker() {
  local product="$1"
  local image="$2"
  cd "${product}"
  echo "*** Running docker build ${image}:${ppa} ***"
  docker build --force-rm --tag="sipwise/${image}:${ppa}" .
  docker tag -f "sipwise/${image}:${ppa}" "${registry}/sipwise/${image}:${ppa}"
}

push_docker() {
  local image="$1"
  echo "*** Pushing image ${image} to internal registry: ***"
  docker push "${registry}/sipwise/${image}:${ppa}"
}

if [ -z "${ppa}" ] || [ "${ppa}" = "none" ] || [ "${ppa}" = '$ppa' ] ; then
  echo "No ppa detected. Nothing to do here"
  exit 0
fi

if [ -z "${release}" ] || [ "${release}" = "none" ] || [ "${release}" = '$release' ] ; then
  echo "*** release is none or empty: set 'trunk' ***"
  release="trunk"
fi

product="ce"
short_release=${release%%-update}
short_release=${short_release##release-}
image="${product}-${short_release}"

pull_docker "${image}"
create_dockerfile "${product}" "${image}"
create_supervisorfile "${product}"
build_docker "${product}" "${image}"
push_docker "${image}"
