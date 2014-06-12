#!/usr/bin/env bash
set -e

while getopts “:u:p:” OPTION; do
  case $OPTION in
    u)
      URI_STRING=$OPTARG
      ;;
    p)
      WEBROOT=$OPTARG
      ;;
  esac
done

# Triage if Pull Request or Deploy Build
if [ -z "$ghprbPullId" ]; then
  # Deploy Build
  /opt/github-drupal-deploy/deploy_remote.sh -u $URI_STRING
else
  # Pull Request, Build ShowCase
  /opt/github-drupal-deploy/build_showcase_local.sh -u $URI_STRING -p $WEBROOT -i $ghprbPullId
fi  
