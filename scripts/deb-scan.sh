#! /bin/sh

DESTINATION=/var/www/metavize
DISTRIBUTION=testing
COMPONENT=metavize
OVERRIDE=override.${DISTRIBUTION}.${COMPONENT}
ARCH=i386

cp -a ${OVERRIDE} ${DESTINATION}/indices/

#
# Generate Packages.gz
#
cd ${DESTINATION}

echo "Building package list..."

dpkg-scanpackages pool/${COMPONENT} indices/${OVERRIDE} > \
	dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages 2> /tmp/out 
if [ $? -ne 0 ] ; then exit ; fi

grep -v "newer version" /tmp/out | grep -v "ignored data" | grep -v "is repeat"

cat dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages | \
	gzip -9 > dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages.gz
if [ $? -ne 0 ] ; then exit ; fi

