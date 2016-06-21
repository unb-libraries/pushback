#!/usr/bin/env bash
set -euo pipefail

# Parse Options
while getopts “:p:” OPTION; do
  case $OPTION in
    p)
      PORT_TO_TEST=$OPTARG
  esac
done

# Test the connection
function testDrupalDeploy() {
  curl -I --fail http://127.0.0.1:${PORT_TO_TEST}/user/login
  return $?
}

CONNECT_RETRY_COUNT=0
CONNECT_RETRY_INTERVAL=60
MAX_CONNECT_RETRIES=7
ENDPOINT_NAME=Drupal

until [ ${CONNECT_RETRY_COUNT} -ge ${MAX_CONNECT_RETRIES} ]
do
  testDrupalDeploy && break
  CONNECT_RETRY_COUNT=$[${CONNECT_RETRY_COUNT}+1]
  echo "${ENDPOINT_NAME} has not deployed. Waiting [${CONNECT_RETRY_COUNT}/${MAX_CONNECT_RETRIES}] in ${CONNECT_RETRY_INTERVAL}(s) "
  sleep ${CONNECT_RETRY_INTERVAL}
done

if [ ${CONNECT_RETRY_COUNT} -ge ${MAX_CONNECT_RETRIES} ]; then
  echo "Connecting to ${ENDPOINT_NAME} failed after ${MAX_CONNECT_RETRIES} attempts!"
  exit 1
fi
