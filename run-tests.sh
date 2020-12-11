#!/bin/sh

if [ -t 1 ] ; then
	echo "WARNING:  running the test suite will result in resetting the stack's state "
	echo "to the SNAPSHOT_TAG specified in .env.  This will wipe out all local changes "
	echo "to Drupal's databases and remove any active content or configuration added since"
	echo "the last snapshot."
	echo ""
	echo "WARNING: continue? [Y/n]"
	read line; if [ $line != "Y" ]; then echo aborting; exit 1 ; fi
fi

reset() {
	printf "\nResetting state to last snapshot\n"
	docker-compose down -v 2>/dev/null
	make -s up 2>/dev/null
}

for testscript in tests/*; do 
	reset
	printf "\n\nRunning ${testscript}\n"
	{ $testscript && echo "PASS: $testscript"; } || { FAILURES="${FAILURES} $testscript" && echo "FAIL: $testscript";}
done

reset

if [ ! -z "${FAILURES}" ] ; then
	printf "\nFAIL: ${FAILURES}\n"
	exit 1
fi


printf "\nSUCCESS: All test passed\n"