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
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
