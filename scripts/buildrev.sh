#!/bin/sh

TOPDIR=`dirname $0`"/../"
REVISIONRB="$TOPDIR/lib/pkgtools/revision.rb"
REVISIONRB_IN="$TOPDIR/lib/pkgtools/revision.rb.in"
SED="/usr/bin/sed"

if [ -d "$TOPDIR/.git" ]; then
	revision=`cd $TOPDIR && git describe`
	date=`date "+%Y/%m/%d"`
	echo "Generating new 'lib/revision.rb' file to match git revision."
	${SED} -E -e "s,%%REVISION%%,${revision},g;s,%%DATE%%,${date},g" \
		"$REVISIONRB_IN" > "$REVISIONRB"
elif [ ! -e "$REVISIONRB" ]; then
	echo "Error: This is not a GIT checkout and 'lib/pkgtools/revision.rb' file does not exsist."
	exit 1
else
	echo "Using 'lib/pkgtools/revision.rb' file from distribution."
fi
