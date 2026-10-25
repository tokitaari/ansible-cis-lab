# Alpine Linux target with OpenRC (busybox init as PID 1).
# Python is intentionally NOT installed - see exercise 0.02.
ARG BASE_IMAGE=alpine:3.24
FROM ${BASE_IMAGE}
ENV container=docker
RUN apk add --no-cache \
      openrc busybox-openrc openssh sudo shadow bash \
 && (apk add --no-cache vsftpd || true)
COPY common/ /opt/lab/
RUN sh /opt/lab/bootstrap.sh alpine alpine
CMD ["/sbin/init"]
