FROM tiredofit/alpine:3.12 as kwmserver-builder

ARG KWMSERVER_REPO_URL
ARG KWMSERVER_VERSION

ENV KWMSERVER_REPO_URL=${KWMSERVER_REPO_URL:-"https://github.com/Kopano-dev/kwmserver"} \
    KWMSERVER_VERSION=${KWMSERVER_VERSION:-"v1.2.0"}

#ADD build-assets/kopano-kwmserver /build-assets

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .kwmserver-build-deps \
                build-base \
                coreutils \
                gettext \
                git \
                go \
                tar \
                && \
    \
    ### Build KWMServer
    git clone ${KWMSERVER_REPO_URL} /usr/src/kwmserver && \
    cd /usr/src/kwmserver && \
    git checkout ${KWMSERVER_VERSION} && \
    \
    if [ -d "/build-assets/src/kwmserver" ] ; then cp -R /build-assets/src/kwmserver/* /usr/src/kwmserver ; fi; \
    if [ -f "/build-assets/scripts/kwmserver.sh" ] ; then /build-assets/scripts/kwmserver.sh ; fi; \
    \
    make && \
    mkdir -p /rootfs/usr/libexec/kopano/ && \
    cp -R ./bin/* /rootfs/usr/libexec/kopano/ && \
    mkdir -p /rootfs/tiredofit && \
    echo "KWMServer ${KWMSERVER_VERSION} built from ${KWMSERVER_REPO_URL} on $(date)" > /rootfs/tiredofit/kwmserver.version && \
    echo "Commit: $(cd /usr/src/kwmserver ; echo $(git rev-parse HEAD))" >> /rootfs/tiredofit/kwmserver.version && \
    cd /rootfs && \
    tar cvfz /kopano-kwmserver.tar.gz . && \
    cd / && \
    apk del .kwmserver-build-deps && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /rootfs

FROM tiredofit/alpine:3.12
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_SMTP=FALSE \
    ZABBIX_HOSTNAME=kwmserver-app

### Move Previously built files from builder image
COPY --from=kwmserver-builder /*.tar.gz /usr/src/kwmserver/

RUN set -x && \
    apk update && \
    apk upgrade && \
    #apk add -t .kwmserver-run-deps \
    #            && \
    \
    ##### Unpack kwmserver
    tar xvfz /usr/src/kwmserver/kopano-kwmserver.tar.gz -C / && \
    rm -rf /usr/src/* && \
    rm -rf /etc/kopano && \
    ln -sf /config /etc/kopano && \
    rm -rf /var/cache/apk/*

ADD install /
