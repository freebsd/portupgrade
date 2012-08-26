#!/bin/sh
#

# PROVIDE: pkgtools
# REQUIRE: ldconfig
# KEYWORD: FreeBSD

. /etc/rc.subr

name=pkgtools

start_cmd=pkgtools_start
stop_cmd=:

[ -z "$pkgtools_libdir" ] && pkgtools_libdir="/usr/local/lib/compat/pkg"

pkgtools_start() {
    if [ -d "$pkgtools_libdir" ]; then
	/sbin/ldconfig -m "$pkgtools_libdir"
    fi
}

load_rc_config $name
run_rc_command "$1"
