# Fedora target with systemd as PID 1
# Fedora 45 is scheduled for late October 2026; switch BASE_IMAGE once it is out.
ARG BASE_IMAGE=fedora:44
FROM ${BASE_IMAGE}
ENV container=docker
RUN dnf -y install \
      systemd openssh-server openssh-clients sudo python3 python3-libdnf5 python3-rpm \
      cronie procps-ng iproute kmod authselect libpwquality passwd findutils \
 && (dnf -y install telnet || true) \
 && (dnf -y install vsftpd || true) \
 && dnf clean all
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh redhat fedora
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
