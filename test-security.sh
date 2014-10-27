#!/usr/bin/env bash
set -e

# Drush
command -v drush >/dev/null 2>&1 || { echo "This script requires drush but it is not globally installed.  Aborting." >&2; exit 1; }

# The directory this script is in.
REAL_PATH=`readlink -f "${BASH_SOURCE[0]}"`
SCRIPT_DIR=`dirname "$REAL_PATH"`

usage() {
  cat $SCRIPT_DIR/README.md |
  # Remove ticks and stars.
  sed -e "s/[\`|\*]//g"
}

while getopts “:u:t:” OPTION; do
  case $OPTION in
    u)
      URI_STRING=$OPTARG
      ;;
    t)
      SNS_TOPIC=$OPTARG
      ;;
  esac
done

COMMITID=`echo "$GIT_COMMIT" | cut -c1-8`
URI_SLUG=`echo "$URI_STRING" | tr . _`
SIXTEEN_CHAR_SLUG=`echo "${COMMITID}_${URI_SLUG}" | cut -c1-16`
DOCROOT="$WORKSPACE/$SIXTEEN_CHAR_SLUG"

if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="drush --yes --verbose --include=$WORKSPACE/drush-scripts --alias-path=$WORKSPACE/aliases"

# Check to make sure drush is working properly, and can access the target site deploy.
$DRUSH status @$URI_STRING --quiet

# Site-Audit
$DRUSH dl site_audit
$DRUSH cc drush
$DRUSH cc all
$DRUSH audit_best_practices
$DRUSH audit_content
$DRUSH audit_cron
$DRUSH audit_database
$DRUSH audit_security
$DRUSH audit_status
$DRUSH audit_users

# Security-Review
$DRUSH dl security_review
$DRUSH en security_review
$DRUSH cc drush
$DRUSH cc all
$DRUSH security-review

# DrupalGeddon on server
$DRUSH drush dl drupalgeddon
$DRUSH cc drush
$DRUSH cc allmail
$DRUSH drupalgeddon-test

# Test files directory for PHP files

# Notify on Success
# /var/opt/github-drupal-deploy/sns_drupal_build.sh -b "$BUILD_USER" -t "$SNS_TOPIC" -u "$URI_STRING" -s "SUCCESS"
