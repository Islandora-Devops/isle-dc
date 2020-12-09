#!/bin/sh


FAIURES=''

for testscript in tests/*; do
	echo "Running ${testscript}"
	$testscript || FAILURES="${FAILURES} $testscript";
done

if [ ! -z "${FAILURES}" ] ; then
	echo "TESTS FAILED: ${FAILURES}"
	exit 1
fi
