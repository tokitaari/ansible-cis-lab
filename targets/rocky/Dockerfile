# Rocky Linux target with systemd as PID 1
# Note: EL10 requires an x86-64-v3 capable CPU (see docs/TROUBLESHOOTING.md).
ARG BASE_IMAGE=rockylinux/rockylinux:10
FROM ${BASE_IMAGE}
ENV container=docker
RUN dnf -y install \
      systemd openssh-server openssh-clients sudo python3 cronie procps-ng \
      iproute kmod authselect libpwquality passwd findutils \
 && (dnf -y install telnet || true) \
 && (dnf -y install vsftpd || true) \
 && dnf clean all
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh redhat rocky
# el10 rsyslog drops its capabilities with libcap-ng; on the GitHub runner (kernel 7.0) that
# failed (capng_apply=-4) and even `rsyslogd -N1` exited 1. Skip it (docs/CONTAINER_LIMITS.md).
RUN mkdir -p /etc/rsyslog.d \
 && printf '%s\n' '# Lab container workaround, see docs/CONTAINER_LIMITS.md' \
      'global(libcapng.enable="off")' > /etc/rsyslog.d/00-lab-container.conf
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
