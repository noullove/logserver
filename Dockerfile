# -------------------------------------------------------------------------------------------------
#
# layer for download and verifying
FROM debian:buster-slim as downloader

ARG MONGO_VERSION
ARG ES_VERSION
ARG GRAYLOG_VERSION
ARG GRAFANA_VERSION

WORKDIR /tmp

COPY mongodb-linux-x86_64-ubuntu1804-${MONGO_VERSION}.tgz /tmp/mongo.tgz

RUN \
  mkdir /opt/mongo && \
  tar --extract --gzip --file "/tmp/mongo.tgz" --strip-components=1 --directory /opt/mongo

RUN \
  install \
    --directory \
    --mode=0755 \
    /opt/mongo/data \
    /opt/mongo/logs

COPY elasticsearch-${ES_VERSION}.tar.gz /tmp/elasticsearch.tgz

RUN \
  mkdir /opt/elasticsearch && \
  tar --extract --gzip --file "/tmp/elasticsearch.tgz" --strip-components=1 --directory /opt/elasticsearch

RUN \
  install \
    --directory \
    --mode=0755 \
    /opt/elasticsearch/config \
    /opt/elasticsearch/data \
    /opt/elasticsearch/logs

COPY config/elasticsearch.yml /opt/elasticsearch/config/

COPY graylog-${GRAYLOG_VERSION}.tgz /tmp/graylog.tgz

RUN \
  mkdir /opt/graylog && \
  tar --extract --gzip --file "/tmp/graylog.tgz" --strip-components=1 --directory /opt/graylog

RUN \
  install \
    --directory \
    --mode=0750 \
    /opt/graylog/data \
    /opt/graylog/data/journal \
    /opt/graylog/data/log \
    /opt/graylog/data/config \
    /opt/graylog/data/plugin \
    /opt/graylog/data/contentpacks \
    /opt/graylog/data/data

COPY config/graylog.conf /opt/graylog/data/config/graylog.conf
COPY config/log4j2.xml /opt/graylog/data/config/log4j2.xml

COPY grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz /tmp/grafana.tgz

RUN \
  mkdir /opt/grafana && \
  tar --extract --gzip --file "/tmp/grafana.tgz" --strip-components=1 --directory /opt/grafana

RUN \
  install \
    --directory \
    --mode=0755 \
    /opt/grafana \
    /opt/grafana/data \
    /opt/grafana/data/log \
    /opt/grafana/data/plugins \
    /opt/grafana/data/png

# -------------------------------------------------------------------------------------------------
#
# final layer
# use the smallest debain with headless openjdk and copying files from download layers
FROM openjdk:8-jre-slim-buster

RUN \
  apt-get update  > /dev/null && \
  apt-get install --no-install-recommends --assume-yes \
    tini libcurl4 procps > /dev/null && \
  apt-get remove --assume-yes --purge \
    apt-utils > /dev/null && \
  rm -f /etc/apt/sources.list.d/* && \
  apt-get clean > /dev/null && \
  apt autoremove --assume-yes > /dev/null && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /usr/share/X11 \
    /usr/share/doc/* 2> /dev/null && \
  addgroup \
    --gid 1000 \
    --quiet \
    logserver && \
  adduser \
    --disabled-password \
    --disabled-login \
    --gecos '' \
    --home /opt \
    --uid 1000 \
    --gid 1000 \
    --quiet \
    logserver && \
    chown -R 1000:0 /opt && \
    chmod 0775 /opt

COPY --from=downloader --chown=logserver /opt /opt
COPY --chown=1000:0 docker-entrypoint.sh /
COPY --chown=1000:0 health_check.sh /

ENV PATH /usr/local/openjdk-8/bin:$PATH

EXPOSE 9000 5044 9200 9300 3000
USER logserver

WORKDIR /opt/graylog

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

# add healthcheck
HEALTHCHECK \
  --interval=10s \
  --timeout=2s \
  --retries=12 \
  CMD /health_check.sh

# -------------------------------------------------------------------------------------------------
# LABEL maintainer="Graylog, Inc. <hello@graylog.com>" \
#       org.label-schema.name="Graylog Docker Image" \
#       org.label-schema.description="Official Graylog Docker image" \
#       org.label-schema.url="https://www.graylog.org/" \
#       org.label-schema.vcs-url="https://github.com/Graylog2/graylog-docker" \
#       org.label-schema.vendor="Graylog, Inc." \
#       org.label-schema.version=${GRAYLOG_VERSION} \
#       org.label-schema.schema-version="1.0" \
#       org.label-schema.build-date=${BUILD_DATE} \
#       com.microscaling.docker.dockerfile="/Dockerfile" \
#       com.microscaling.license="Apache 2.0"
