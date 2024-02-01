#!/bin/sh

MAINTAINPORT_DIR=/root/maintainport/
SSH_DIR=/root/.ssh/

FREEBSDVERSION=13.1
JAILNAME=13

msg() {
  printf ">> %s\n" "$*"
}

pkg_setup() {
  msg "Create pkg/FreeBSD.conf"
  cat << EOF > /etc/pkg/FreeBSD.conf
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOF
}

pkg_install() {
  msg "Install base packages"
  pkg install -y pkg
  pkg install -y ccache colordiff git-tiny lftp portlint poudriere subversion tmux vim-tiny || exit 1
}

poudriere_setup() {
  msg "Set up poudriere"
  exists_ports || poudriere ports -c
  exists_jail || poudriere jail -c -j "${JAILNAME}" -v ${FREEBSDVERSION}-RELEASE
  mkdir -p /usr/local/poudriere/data/distfiles/
}

exists_ports() {
  poudriere ports -l | grep -q ^default
}

exists_jail() {
  poudriere jail -l | grep -q "${JAILNAME}"
}

poudriere_conf() {
  msg "Create poudriere.conf"
  cat << EOF > /usr/local/etc/poudriere.conf
NO_ZFS=yes
FREEBSD_HOST=_PROTO_://_CHANGE_THIS_
RESOLV_CONF=/etc/resolv.conf
BASEFS=/usr/local/poudriere
POUDRIERE_DATA=\${BASEFS}/data
USE_PORTLINT=yes
USE_TMPFS=no
DISTFILES_CACHE=/usr/local/poudriere/data/distfiles
CCACHE_DIR=/var/cache/ccache
ALLOW_MAKE_JOBS=yes
EOF
}

get_passwords() {
  msg "Decrypting passwords"
  mkdir -p ${SSH_DIR}
  sleep 1
  get_password_output_decrypt ${MAINTAINPORT_DIR}/password-freebsd password-freebsd.enc
}

get_password_output_decrypt() {
  [ -e "${1}" ] || gpg --output $1 --decrypt $2
}

root_cshrc() {
  msg "Create root/.cshrc"
cat << EOF > /root/.cshrc
setenv CLICOLOR 1
setenv EDITOR vim
setenv LSCOLORS GefhcxdxgXegedabagacad
setenv PAGER "less -R"

set autolist = ambiguous
EOF
}

ccache_setup() {
  mkdir -p /var/cache/ccache/
}

cron_poudriere() {
  msg "Create poudriere cron file"
cat << EOF > /etc/cron.d/poudriere
0 0 * * * root /usr/local/bin/poudriere ports -u
EOF
}


pkg_setup
pkg_install
poudriere_setup
poudriere_conf
get_passwords
root_cshrc
ccache_setup
cron_poudriere
