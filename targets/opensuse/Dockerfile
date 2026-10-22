# openSUSE Leap target with systemd as PID 1
ARG BASE_IMAGE=opensuse/leap:16.0
FROM ${BASE_IMAGE}
ENV container=docker
RUN zypper -n --gpg-auto-import-keys refresh \
 && zypper -n install --no-recommends \
      systemd dbus-1 openssh-server openssh-clients sudo python3 cronie procps \
      iproute2 kmod shadow findutils \
 && (zypper -n install --no-recommends python3-rpm || zypper -n install --no-recommends python313-rpm || true) \
 && (zypper -n install --no-recommends telnet || true) \
 && (zypper -n install --no-recommends vsftpd || true) \
 && zypper clean -a
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh suse opensuse
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
