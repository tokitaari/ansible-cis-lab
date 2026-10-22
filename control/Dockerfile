# Ansible control node
ARG BASE_IMAGE=python:3.13-slim-trixie
FROM ${BASE_IMAGE}
# Ansible community package 14 = ansible-core 2.21 + curated collections
# (ansible.posix, community.general, ...). Override with --build-arg.
ARG ANSIBLE_VERSION=14.*
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-client git less nano vim-tiny jq procps iputils-ping bash-completion \
 && rm -rf /var/lib/apt/lists/*
RUN pip install "ansible==${ANSIBLE_VERSION}" ansible-lint yamllint passlib jmespath
COPY lab /usr/local/bin/lab
COPY entrypoint.sh /usr/local/bin/lab-entrypoint
COPY bashrc.sh /etc/lab-bashrc.sh
RUN chmod 0755 /usr/local/bin/lab /usr/local/bin/lab-entrypoint \
 && printf '\n[ -f /etc/lab-bashrc.sh ] && . /etc/lab-bashrc.sh\n' >> /etc/bash.bashrc
WORKDIR /lab
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
CMD ["sleep", "infinity"]
