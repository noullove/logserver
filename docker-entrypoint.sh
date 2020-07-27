#!/bin/bash

set -e

# shellcheck disable=SC1091
source /etc/profile

# Delete outdated PID file
[[ -e /tmp/graylog.pid ]] && rm --force /tmp/graylog.pid

export TZ=Asia/Seoul

GRAYLOG_HOME=/opt/graylog
GRAYLOG_SERVER_JAVA_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:NewRatio=1 -XX:MaxMetaspaceSize=256m -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow"

mongo() {
  /opt/mongo/bin/mongod \
    --fork \
    --logpath /opt/mongo/logs/mongod.log \
    --dbpath /opt/mongo/data
}

elasticsearch() {
    #su - logserver -c "export JAVA_HOME=/usr/local/openjdk-8;/opt/elasticsearch/bin/elasticsearch -d -p /opt/elasticsearch/es.pid"
    export JAVA_HOME=/usr/local/openjdk-8;/opt/elasticsearch/bin/elasticsearch -d -p /opt/elasticsearch/es.pid
}

graylog() {

  /usr/local/openjdk-8/bin/java \
    ${GRAYLOG_SERVER_JAVA_OPTS} \
    -jar \
    -Dlog4j.configurationFile="${GRAYLOG_HOME}/data/config/log4j2.xml" \
    -Djava.library.path="${GRAYLOG_HOME}/lib/sigar/" \
    -Dgraylog2.installation_source=docker \
    "${GRAYLOG_HOME}/graylog.jar" \
    server \
    -f "${GRAYLOG_HOME}/data/config/graylog.conf"
}

grafana() {
  /opt/grafana/bin/grafana-server -homepath=/opt/grafana -pidfile=/opt/grafana/grafana.pid > /dev/null 2>&1 &
}

run() {
  mongo
  elasticsearch
  grafana
  graylog
}

run
