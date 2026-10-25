# Arch Linux target with systemd as PID 1 (rolling release)
ARG BASE_IMAGE=archlinux:latest
FROM ${BASE_IMAGE}
ENV container=docker
RUN pacman -Syu --noconfirm --needed \
      openssh sudo python cronie procps-ng iproute2 kmod which \
 && (pacman -S --noconfirm --needed vsftpd || true) \
 && pacman -Scc --noconfirm
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh arch arch
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
