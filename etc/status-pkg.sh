#!/bin/sh -
#
# status-pkg - a replacement of the weekly status-pkg report script
#

# If there is a global system configuration file, suck it in.
#
if [ -r /etc/defaults/periodic.conf ]
then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

localbase=/usr/local

case "$weekly_status_pkg_enable" in
    [Yy][Ee][Ss])
	echo ""
	echo "Check for out of date packages:"

	rc=$($localbase/sbin/portversion -vOL '=' |
	    sed -e 's/^/  /' |
	    tee /dev/stderr |
	    wc -l)
	if [ $rc -gt 1 ]
	then
	    rc=1
	    echo ""
	    echo "  Run '$localbase/sbin/portversion -c' to produce an updater script."
	fi;;

    *)  rc=0;;
esac

exit $rc
