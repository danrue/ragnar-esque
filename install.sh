#!/bin/bash

ROOTDIR=$(readlink -f $(dirname $0))
INSTALL_FILES="build-kernel build-randconfig-kernel deploy-kernel ragnar-lib rebuild-oe"

home_bin_dir=$HOME/bin
mkdir -p ${home_bin_dir}

cd ${home_bin_dir}
for file in $INSTALL_FILES; do
    ln -sf ${ROOTDIR}/${file} ${file}
done

## vim: set sw=4 sts=4 et foldmethod=syntax : ##
