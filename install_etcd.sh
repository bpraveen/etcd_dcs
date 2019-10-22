#!/bin/sh
# -*- mode: sh; coding: us-ascii; indent-tabs-mode: nil -*-
# vim: set filetype=sh fileencoding=utf-8 expandtab sw=4 sts=4:
#
# Install etcd.
# PB, created 23-Nov-2018
#

if [ $# -lt 1 ] ; then echo "usage: $0 <ETCD_INSTALLATION_DIRECTORY_PATH>" >&2 ; exit 1 ; fi

etcd_dir=$1

ETCD_VER=v3.3.10

# choose either URL
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}

rm -f ${etcd_dir}/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf ${etcd_dir}/etcd-download-test && mkdir -p ${etcd_dir}/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o ${etcd_dir}/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf ${etcd_dir}/etcd-${ETCD_VER}-linux-amd64.tar.gz -C ${etcd_dir}/etcd-download-test --strip-components=1
rm -f ${etcd_dir}/etcd-${ETCD_VER}-linux-amd64.tar.gz

${etcd_dir}/etcd-download-test/etcd --version
ETCDCTL_API=3 ${etcd_dir}/etcd-download-test/etcdctl version
