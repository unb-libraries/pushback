#!/usr/bin/env bash

# Requirements
command -v docker >/dev/null 2>&1 || { echo "This script requires docker but it is not globally installed.  Aborting." >&2; exit 1; }
if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# The directory this script is in.
REAL_PATH=`readlink -f "${BASH_SOURCE[0]}"`
SCRIPT_DIR=`dirname "$REAL_PATH"`

# Parse Options
while getopts “:u:t:b:v:p:d:m:a:s:n:e:” OPTION; do
  case $OPTION in
    u)
      URI_STRING=$OPTARG
      ;;
    t)
      SNS_TOPIC=$OPTARG
      ;;
    b)
      DRUPAL_IMAGE_TAG=$OPTARG
      ;;
    v)
      VOLUME_MOUNT_POINT=$OPTARG
      ;;
    p)
      PORT_TO_DEPLOY=$OPTARG
      ;;
    d)
      DRUPAL_DB_PASSWORD=$OPTARG
      ;;
    m)
      MYSQL_ROOT_PASSWORD=$OPTARG
      ;;
    a)
      DRUPAL_ADMIN_ACCOUNT_PASS=$OPTARG
      ;;
    s)
      DRUPAL_TESTING_TOOLS=$OPTARG
      ;;
    n)
      NR_INSTALL_KEY=$OPTARG
      ;;
    e)
      DEPLOY_ENV=$OPTARG
  esac
done

# Init some variables used later.
CONTAINER_ID=$URI_STRING
COMMITID=`echo "$GIT_COMMIT" | cut -c1-8`
URI_SLUG=`echo "$URI_STRING" | tr . _`
SIXTEEN_CHAR_SLUG=`echo "${COMMITID}_${URI_SLUG}" | cut -c1-16`

# Ensure a container's volume exists.
check_create_container_volume ()
{
  VOLUME_INSPECT=$(docker volume inspect "$1" 2> /dev/null)
  if [ $? -eq 1 ]; then
    echo "No ${1} volume found, creating one for [$1]"
    docker volume create --name "$1"
  fi
}

# Stop and remove a container if it is running.
stop_running_container ()
{
  CONTAINER_RUNNING=$(docker inspect --format="{{ .State.Running }}" "$1" 2> /dev/null)
  # Is this container running currently?
  if [ $? -eq 1 ]; then
    # Container does not exist. We do not have to clean up.
    echo "Container not found [$1]"
  else
    CONTAINER_GHOST=$(docker inspect --format="{{ .State.Dead }}" "$1")
    if [ "$RUNNING" == "false" ]; then
      echo "Removing previously stopped container [$1]"
    elif [ "$GHOST" == "true" ]; then
      echo "Removing ghosted container [$1]"
    else
      echo "Stopping running container [$1]"
      echo "Removing previously stopped container [$1]"
    fi
    docker rm --force "$1"
  fi
}

## MySQL Image
#
check_create_container_volume "${CONTAINER_ID}_mysql"
stop_running_container "${CONTAINER_ID}_mysql"
set -e

docker pull mysql:5.6
docker run \
       --name ${CONTAINER_ID}_mysql \
       --detach \
       -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
       -v ${CONTAINER_ID}_mysql:/var/lib/mysql \
       mysql:5.6

# Get the IP of the deployed MySQL container.
sleep 5
MYSQL_HOST_IP="$(docker exec ${CONTAINER_ID}_mysql /sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"
echo "MySQL IP found as : $MYSQL_HOST_IP"
set +e


## Drupal Image
#
check_create_container_volume "$CONTAINER_ID"
stop_running_container "$CONTAINER_ID"
set -e

cd $WORKSPACE
docker pull unblibraries/drupal:$DRUPAL_IMAGE_TAG
docker build --no-cache -t unblibdev/$CONTAINER_ID .

docker run \
       --name $CONTAINER_ID \
       --detach \
       --link ${CONTAINER_ID}_mysql \
       -e DRUPAL_DB_PASSWORD=$DRUPAL_DB_PASSWORD \
       -e DRUPAL_ADMIN_ACCOUNT_PASS=$DRUPAL_ADMIN_ACCOUNT_PASS \
       -e DRUPAL_TESTING_TOOLS=$DRUPAL_TESTING_TOOLS \
       -e DRUPAL_SITE_URI=$URI_STRING \
       -e DEPLOY_ENV=$DEPLOY_ENV \
       -e MYSQL_HOSTNAME=$MYSQL_HOST_IP \
       -e MYSQL_PORT=3306 \
       -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
       -e NR_INSTALL_KEY=$NR_INSTALL_KEY \
       -v $CONTAINER_ID:$VOLUME_MOUNT_POINT \
       -p $PORT_TO_DEPLOY:80 \
       unblibdev/$CONTAINER_ID
