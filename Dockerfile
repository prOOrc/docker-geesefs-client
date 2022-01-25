FROM golang:1.16-alpine as build

ARG GEESEFS_VERSION=v0.30.5

RUN apk --no-cache add \
    git && \
  git clone https://github.com/yandex-cloud/geesefs.git && \
  cd geesefs && \
  git checkout tags/${GEESEFS_VERSION} && \
  CGO_ENABLED=0 GOOS=linux go install

FROM alpine

# Metadata
LABEL MAINTAINER=proorc9@gmail.com
LABEL org.opencontainers.image.title="geesefs"
LABEL org.opencontainers.image.description="Mount S3 buckets from within a container and expose them to host/containers"
LABEL org.opencontainers.image.authors="Ilya Obukhov <proorc9@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/prOOrc/docker-geesefs-client"
LABEL org.opencontainers.image.documentation="https://github.com/prOOrc/docker-geesefs-client/README.md"
LABEL org.opencontainers.image.source="https://github.com/prOOrc/docker-geesefs-client/Dockerfile"

COPY --from=build /go/bin/geesefs /usr/bin/geesefs

# Specify URL and secrets. When using AWS_S3_SECRET_ACCESS_KEY_FILE, the secret
# key will be read from that file itself, which helps passing further passwords
# using Docker secrets. You can either specify the path to an authorisation
# file, set environment variables with the key and the secret.
ENV AWS_S3_URL=https://storage.yandexcloud.net
ENV AWS_S3_ACCESS_KEY_ID=
ENV AWS_S3_SECRET_ACCESS_KEY=
ENV AWS_S3_SECRET_ACCESS_KEY_FILE=
ENV AWS_S3_AUTHFILE=
ENV AWS_S3_BUCKET=

# User and group ID of share owner
ENV RUN_AS=
ENV UID=0
ENV GID=0

# Location of directory where to mount the drive into the container.
ENV AWS_S3_MOUNT=/opt/geesefs/bucket

# geesefs tuning
ENV GEESEFS_DEBUG=0
ENV GEESEFS_ARGS=

RUN mkdir /opt/geesefs && \
    apk --no-cache add \
      ca-certificates \
      mailcap \
      fuse \
      libxml2 \
      libcurl \
      libgcc \
      libstdc++ \
      tini && \
    geesefs --version

# allow access to volume by different user to enable UIDs other than root when using volumes
RUN echo user_allow_other >> /etc/fuse.conf

COPY *.sh /usr/local/bin/

WORKDIR /opt/geesefs

# Following should match the AWS_S3_MOUNT environment variable.
VOLUME [ "/opt/geesefs/bucket" ]

# The default is to perform all system-level mounting as part of the entrypoint
# to then have a command that will keep listing the files under the main share.
# Listing the files will keep the share active and avoid that the remote server
# closes the connection.
ENTRYPOINT [ "tini", "-g", "--", "docker-entrypoint.sh" ]
CMD [ "empty.sh" ]