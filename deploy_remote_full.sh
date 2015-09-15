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

while getopts “:u:t:l:” OPTION; do
  case $OPTION in
    u)
      URI_STRING=$OPTARG
      ;;
    t)
      SNS_TOPIC=$OPTARG
      ;;
    l)
      URI_TO_TEST=$OPTARG
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

# Remove Previous Builds of This Hash
rm -rf "$DOCROOT"

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="drush --yes --verbose --include=$WORKSPACE/drush-scripts --alias-path=$WORKSPACE/aliases"

# Check to make sure drush is working properly, and can access the target site deploy.
$DRUSH status @$URI_STRING --quiet

# Build Site
cd "$WORKSPACE/make"
$DRUSH make "$URI_SLUG.makefile" --contrib-destination="sites/all" "$DOCROOT"

# Copy settings.php into tree before deployment
cp -p "$WORKSPACE/settings/settings.php" "$DOCROOT/sites/default"

# Copy profiles into tree before deployment
cp -rp "$WORKSPACE/profiles" "$DOCROOT"

# Copy Tree 
cd "$DOCROOT"
$DRUSH rsync @self @$URI_STRING --delete --omit-dir-times --chmod=o+r --perms --include-conf --exclude=sites/default/files/

# Copy .htaccess to files dir
$DRUSH rsync "$SCRIPT_DIR/files.htaccess" @$URI_STRING:%files/.htaccess --omit-dir-times --chmod=og-w --perms --inplace

# Clear Cache
$DRUSH cc all @$URI_STRING

# Perform any database updates required
$DRUSH @$URI_STRING updb

# Ensure anonymous users do not get a registration form
$DRUSH @$URI_STRING vset user_register 0

# Enable Preprocessing for JS/CSS
$DRUSH @$URI_STRING vset preprocess_css 1
$DRUSH @$URI_STRING vset preprocess_js 1

# Enable anonmymous Caching
$DRUSH @$URI_STRING vset cache 1

# Cache blocks for Anonymous
$DRUSH @$URI_STRING vset block_cache 1

# Turn on page compression
$DRUSH @$URI_STRING vset page_compression 1

# Do not display errors to users
$DRUSH @$URI_STRING vset error_level 0

# Run Casper Tests
if test -n "$(find $WORKSPACE/tests -maxdepth 1 -name '*.js' -print -quit)"
then
  cd "$WORKSPACE/tests"
  find . -type f -print0 | xargs -0 sed -i "s|{{URI_TO_TEST}}|$URI_TO_TEST|g"
  casperjs --no-colors --verbose test *.js
fi

# Clean up build dir.
cd "$WORKSPACE"
rm -rf "$DOCROOT"

# Notify on Success
/var/opt/github-drupal-deploy/sns_drupal_build.sh -b "$BUILD_USER" -t "$SNS_TOPIC" -u "$URI_STRING" -s "SUCCESS"
