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

# Drupalgeddon
rm -rf ~/.drush/drupalgeddon
drush dl --yes drupalgeddon
rm -rf ~/.drush/cache
drush cc all --yes
drush drupalgeddon-test

# Site-Audit
rm -rf ~/.drush/site_audit
drush dl --yes site_audit
rm -rf ~/.drush/cache
drush cc all --yes
drush audit_best_practices
drush audit_content
drush audit_cron
drush audit_database
drush audit_security
drush audit_status
drush audit_users

# Security-Review
drush dl --yes security_review
drush en --yes security_review
rm -rf ~/.drush/cache
drush cc all --yes
drush security-review

# Test files directory for PHP files

# Notify on Success
/var/opt/github-drupal-deploy/sns_drupal_build.sh -b "$BUILD_USER" -t "$SNS_TOPIC" -u "$URI_STRING" -s "SUCCESS"
