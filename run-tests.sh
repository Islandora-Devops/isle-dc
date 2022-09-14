#!/bin/sh
#set -vx

warn() {
    if [ -t 1 ] ; then
      echo "WARNING:  running the test suite will result in resetting the stack's state "
      echo "to the SNAPSHOT_TAG specified in .env.  This will wipe out all local changes "
      echo "to Drupal's databases and remove any active content or configuration added since"
      echo "the last snapshot."
      echo ""
      echo "WARNING: continue? [Y/n]"
      read line; line=$(echo "$line" | tr a-z A-Z); if [ $line != "Y" ]; then echo aborting; exit 1 ; fi
  fi
}

reset() {
  printf "\nResetting state to last snapshot\n"
  docker-compose down -v 2>/dev/null || true
  make -s up 2>/dev/null
}

# Execute the specified test in a subshell, provided the contents of .env as its environment and tests/.funcs.sh for
# common shell functions
execute() {
  local testscript="$1"

  if [ ! -f "${testscript}" ] ; then
    origtestscript="${testscript}"
    testscript="${testscript}.sh"
  fi

  if [ ! -f "${testscript}" ] ; then
    echo "Checked for the presence of ${origtestscript} and ${testscript}, but neither existed."
    echo "exiting"
    exit 1
  fi

  bash -c "set -a && \
           sed -e 's/^REQUIRED_SERIVCES=\(.*\)/REQUIRED_SERIVCES="\1"/' < .env > /tmp/test-env && \
           source /tmp/test-env && \
           export ENV_FILE=/tmp/test-env && \
           source tests/.includes.sh && \
           ${testscript}" || { FAILURES="${FAILURES} $testscript" && echo "FAIL: $testscript"; }
}

# If a test is specified, execute it using the existing state, otherwise run all tests, resetting the state for each
if [ -n "$1" ] ; then
  reset
  testscript="$1"
  printf "\n\nRunning ${testscript} using the current Drupal state (i.e. no reset of the environment will occur)\n"
  execute tests/${testscript}
else
  warn
  for testscript in tests/*.sh; do
    reset
    printf "\n\nRunning ${testscript}\n"
    execute ${testscript}
  done
  reset
fi

if [ ! -z "${FAILURES}" ] ; then
  printf "\nFAIL: ${FAILURES}\n"
  exit 1
fi

printf "\nSUCCESS: All test passed\n"
