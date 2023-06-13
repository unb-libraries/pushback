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
COREVER=`grep core "make/$URI_SLUG.makefile"|awk '{print $2}'`

if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="drush --yes --include=$WORKSPACE/drush-scripts --alias-path=$WORKSPACE/aliases"

# Check to make sure drush is working properly, and can access the target site deploy.
$DRUSH status @$URI_STRING --quiet

# Site-Audit
$DRUSH @$URI_STRING dl site_audit-7.x-1.x
if [[ "8.x" == "$COREVER" ]]; then
  $DRUSH @$URI_STRING cache-rebuild
  $DRUSH @$URI_STRING audit-best-practices
  $DRUSH @$URI_STRING audit-content
  $DRUSH @$URI_STRING audit-cron
  $DRUSH @$URI_STRING audit-database
  $DRUSH @$URI_STRING audit-status
  $DRUSH @$URI_STRING audit-users
else
  $DRUSH @$URI_STRING cc drush
  $DRUSH @$URI_STRING cc all
  $DRUSH @$URI_STRING audit_best_practices
  $DRUSH @$URI_STRING audit_content
  $DRUSH @$URI_STRING audit_cron
  $DRUSH @$URI_STRING audit_database
  $DRUSH @$URI_STRING audit_status
  $DRUSH @$URI_STRING audit_users
fi

# Security-Review
$DRUSH @$URI_STRING dl security_review
$DRUSH @$URI_STRING en security_review
if [[ "8.x" == "$COREVER" ]]; then
  $DRUSH @$URI_STRING cache-rebuild
else
  $DRUSH @$URI_STRING cc drush
  $DRUSH @$URI_STRING cc all
fi
$DRUSH @$URI_STRING security-review --skip=file_perms

# Test files directory for PHP files

# Notify on Success
# /var/opt/github-drupal-deploy/sns_drupal_build.sh -b "$BUILD_USER" -t "$SNS_TOPIC" -u "$URI_STRING" -s "SUCCESS"
