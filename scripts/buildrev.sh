#!/bin/sh

TOPDIR=`dirname $0`"/../"
REVISIONRB="$TOPDIR/lib/pkgtools/revision.rb"
REVISIONRB_IN="$TOPDIR/lib/pkgtools/revision.rb.in"
SED="/usr/bin/sed"

if [ -e "$REVISIONRB" ]; then
	echo "Using 'lib/pkgtools/revision.rb' file from distribution."
	exit 0
fi

if [ -d "$TOPDIR/.git" ]; then
	revision=`cd $TOPDIR && git describe`
else
	# Handle git-format
	revision='$Format:%H$'
fi
date=`date "+%Y/%m/%d"`
echo "Generating new 'lib/pkgtools/revision.rb' file to match git revision."
${SED} -E -e "s,%%REVISION%%,${revision},g;s,%%DATE%%,${date},g" \
	"$REVISIONRB_IN" > "$REVISIONRB"
