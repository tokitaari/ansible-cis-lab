# Ansible control node
ARG BASE_IMAGE=python:3.13-slim-trixie
FROM ${BASE_IMAGE}
# Ansible community package 14 = ansible-core 2.21 + curated collections
# (ansible.posix, community.general, ...). Override with --build-arg.
ARG ANSIBLE_VERSION=14.*
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
# UTF-8 locale: without it 'less' treats the exercise texts (★, ä, ö) as binary
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 LESSCHARSET=utf-8 PAGER="less -FRX" LESS="-FRX" \
    LESSOPEN="|/usr/local/bin/lab-lesspipe %s" EDITOR=vim VISUAL=vim TERM=xterm-256color
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-client git less nano vim jq procps iputils-ping bash-completion \
 && rm -rf /var/lib/apt/lists/*
RUN pip install "ansible==${ANSIBLE_VERSION}" ansible-lint yamllint passlib jmespath rich
# oh-my-bash, system-wide (read-only); per-user cache goes to ~/.local/state
ARG OMB_REF=master
RUN git clone --depth 1 --branch "${OMB_REF}" https://github.com/ohmybash/oh-my-bash.git /opt/oh-my-bash \
 && rm -rf /opt/oh-my-bash/.git
COPY skel-bashrc /etc/skel/.bashrc
COPY vimrc.local /etc/vim/vimrc.local
COPY lab /usr/local/bin/lab
COPY lab-view /usr/local/bin/lab-view
COPY lab-lesspipe /usr/local/bin/lab-lesspipe
COPY entrypoint.sh /usr/local/bin/lab-entrypoint
COPY bashrc.sh /etc/lab-bashrc.sh
RUN chmod 0755 /usr/local/bin/lab /usr/local/bin/lab-view /usr/local/bin/lab-lesspipe /usr/local/bin/lab-entrypoint \
 && printf '\n[ -f /etc/lab-bashrc.sh ] && . /etc/lab-bashrc.sh\n' >> /etc/bash.bashrc
WORKDIR /lab
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
CMD ["sleep", "infinity"]
