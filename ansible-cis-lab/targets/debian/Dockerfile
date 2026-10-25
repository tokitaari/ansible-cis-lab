# Debian (stable) target with systemd as PID 1
ARG BASE_IMAGE=debian:13
FROM ${BASE_IMAGE}
ENV container=docker DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus openssh-server sudo python3 python3-apt \
      ca-certificates cron procps iproute2 kmod less vim-tiny \
 && (apt-get install -y --no-install-recommends telnet || true) \
 && (apt-get install -y --no-install-recommends vsftpd || true) \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh debian debian
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
