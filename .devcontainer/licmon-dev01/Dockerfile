ARG __alpine_version=3.22.0
FROM alpine:${__alpine_version}

# Alpine packages versions: https://pkgs.alpinelinux.org/
ARG __curl_version=8.14.1-r2
ARG __git_version=2.49.1-r0
ARG __go_version=1.24.10-r0
ARG __make_version=4.4.1-r3
ARG __mandoc_version=1.14.6-r13
ARG __musl_dev_version=1.2.5-r10
ARG __sqlite_dev_version=3.49.2-r1
ARG __shellcheck_version=0.10.0-r2
ARG __shunit2_version=2.1.8-r1
ARG __golang_ci_version=v2.3.0

ARG __gid=1001
ARG __gname=dev
ARG __uid=1001
ARG __uname=dev
ARG __user_home=/home/${__uname}

# Configure Go
ENV GOROOT=/usr/lib/go
ENV GOPATH=/opt/go
ENV PATH=${GOPATH}/bin:$PATH

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl=${__curl_version} \
      git=${__git_version} \
      go=${__go_version} \
      make=${__make_version} \
      mandoc=${__mandoc_version} \
      musl-dev=${__musl_dev_version} \
      shellcheck=${__shellcheck_version} \
      shunit2=${__shunit2_version} \
      sqlite-dev=${__sqlite_dev_version} \
    && mkdir -p ${GOPATH}/src ${GOPATH}/bin \
    && wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s ${__golang_ci_version} \
    && addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__user_home} ${__uname} \
    && chown -R ${__uname}:${__gname} ${GOPATH}

# minimal healthcheck, we do not really need it here
HEALTHCHECK CMD exit 0

USER ${__uname}
