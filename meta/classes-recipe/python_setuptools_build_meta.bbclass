#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

inherit setuptools3-base python_pep517

DEPENDS += "python3-setuptools-native python3-wheel-native"

B = "${WORKDIR}/build"
do_configure[cleandirs] += "${B}"

do_compile:prepend() {
    # Write an extra config file to build in parallel
    export DIST_EXTRA_CONFIG=${WORKDIR}/setuptools-extra.cfg
    cat <<EOF >$DIST_EXTRA_CONFIG
[build]
build_base = ${B}
[build_ext]
parallel = ${@oe.utils.parallel_make(d)}
EOF
}
