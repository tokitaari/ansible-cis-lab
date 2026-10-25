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
      openssh-client git less nano vim jq procps iputils-ping bash-completion tzdata \
 && rm -rf /var/lib/apt/lists/*
RUN pip install "ansible==${ANSIBLE_VERSION}" ansible-lint yamllint passlib jmespath rich
# oh-my-bash, system-wide (read-only); per-user cache goes to ~/.local/state
ARG OMB_REF=master
RUN git clone --depth 1 --branch "${OMB_REF}" https://github.com/ohmybash/oh-my-bash.git /opt/oh-my-bash \
 && rm -rf /opt/oh-my-bash/.git
# Baked copies (fallback) - the live versions come from the mounted repo /lab/control/
COPY lab lab-view lab-lesspipe skel-bashrc bashrc.sh vimrc.local /usr/local/lib/lab/
COPY live-wrapper /usr/local/lib/lab/live-wrapper
COPY entrypoint.sh /usr/local/bin/lab-entrypoint
RUN chmod 0755 /usr/local/lib/lab/* /usr/local/bin/lab-entrypoint \
 && for t in lab lab-view lab-lesspipe; do ln -sf /usr/local/lib/lab/live-wrapper "/usr/local/bin/$t"; done \
 && printf '%s\n' '# lab: load the current shell config from the repository' \
      'if [ -r /lab/control/skel-bashrc ]; then . /lab/control/skel-bashrc; else . /usr/local/lib/lab/skel-bashrc; fi' \
      > /etc/skel/.bashrc \
 && printf '\n%s\n' 'if [ -r /lab/control/bashrc.sh ]; then . /lab/control/bashrc.sh; else . /usr/local/lib/lab/bashrc.sh; fi' \
      >> /etc/bash.bashrc \
 && printf '%s\n' '" lab: load the current vim config from the repository' \
      'if filereadable("/lab/control/vimrc.local") | source /lab/control/vimrc.local | else | source /usr/local/lib/lab/vimrc.local | endif' \
      > /etc/vim/vimrc.local
WORKDIR /lab
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
CMD ["sleep", "infinity"]
