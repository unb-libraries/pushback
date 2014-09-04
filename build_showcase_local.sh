#!/usr/bin/env bash
set -e
source /var/opt/github-drupal-deploy/github-drupal-deploy.cfg

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

while getopts “:u:p:i:” OPTION; do
  case $OPTION in
    u)
      URI_STRING=$OPTARG
      ;;
    p)
      WEBROOT=$OPTARG
      ;;
    i)
      GITHUBPRID=$OPTARG
      ;;
  esac
done

if [[ -z $WEBROOT ]]; then
  $GITHUBPRID="1"
fi

URI_SLUG=`echo "$URI_STRING" | tr . _`
SIXTEEN_CHAR_SLUG=`echo pull_${GITHUBPRID}_${URI_SLUG} | cut -c1-16`

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $WEBROOT ]] || [[ -z $COMMITID ]]; then
  usage
  exit 1
fi

if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="drush --yes --verbose --include=$WORKSPACE/drush-scripts --alias-path=$WORKSPACE/aliases"

# The docroot of the new Drupal directory.
DOCROOT=$WEBROOT/$URI_STRING/$SIXTEEN_CHAR_SLUG
# The base prefix to use for the database tables.
PREFIX="commit_"
# The unique prefix to use for just this pull request.
DB_PREFIX="${PREFIX}${GIT_COMMIT}_"
# The drush options for the Drupal destination site. Eventually, we could open
# this up to allow users to specify a drush site alias, but for now, we'll just
# manually specify the root and uri options.
DESTINATION="--root=$DOCROOT --uri=default"

# Check to See if the Path Exists
if [ -d "$DOCROOT" ]; then
  rm -rf $DOCROOT  
fi

# Check to make sure drush is working properly, and can access the source site.
$DRUSH status @$URI_STRING --quiet

# Build Site
$DRUSH make make/$URI_SLUG.makefile $DESTINATION $DOCROOT

# Create Database And Grant Privileges
DATABASE_HOST="localhost"
DATABASE_NAME=$SIXTEEN_CHAR_SLUG
DATABASE_USER=$SIXTEEN_CHAR_SLUG
DATABASE_PASSWORD=$SIXTEEN_CHAR_SLUG
MYSQL_R_PW=$LOCAL_MYSQL_ROOT_PASSWORD

mysql -u root -p$MYSQL_R_PW -e "CREATE DATABASE $DATABASE_NAME"
mysql -u root -p$MYSQL_R_PW -e "GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_PASSWORD'"
mysql -u root -p$MYSQL_R_PW -e "FLUSH PRIVILEGES"

# Modify and copy settings
cd $WORKSPACE/settings
sed -i "s/'database' => '.*',/'database' => '$DATABASE_NAME',/g" settings.php
sed -i "s/'username' => '.*',/'username' => '$DATABASE_USER',/g" settings.php
sed -i "s/'password' => '.*',/'password' => '$DATABASE_PASSWORD',/g" settings.php
sed -i "s/'host' => '.*',/'host' => '$DATABASE_HOST',/g" settings.php
rsync settings.php $DOCROOT/sites/default

# Copy install profile
mkdir $DOCROOT/profiles/$URI_SLUG
cd $WORKSPACE/profile
rsync $URI_SLUG* $DOCROOT/profiles/$URI_SLUG

# Copy Aliases File
cd $WORKSPACE/aliases
rsync *aliases.drushrc.php $DOCROOT

# Install Site
cd $DOCROOT
$DRUSH site-install unbherbarium_ca

# Transfer files locally
# This must happen before the database sync, since the DB sync will alter
# The target of the files using @self
$DRUSH rsync @$URI_STRING:%files @self:%files --omit-dir-times --no-p --no-o --exclude-paths="css:js:styles:imagecache:ctools:tmp"

# Transfer remote DB
$DRUSH sql-sync @$URI_STRING @self

# Change File Permissions
chmod -R 777 $DOCROOT/sites/default/files

# Set filepath var
$DRUSH $DESTINATION vset file_public_path sites/default/files
$DRUSH $DESTINATION vset file_private_path sites/default/files

# Rebuild Registry
$DRUSH $DESTINATION registry-rebuild

# Clear Cache
$DRUSH $DESTINATION cc all 

# Build Body of Message
BODYOFMESSAGE="This Pull Request (https://github.com/unb-libraries/build-profile-$URI_STRING/pull/$GITHUBPRID) Has Been Built successfully!

A live version is available at http://builds.lib.unb.ca/$URI_STRING/$SIXTEEN_CHAR_SLUG/
To tear this request down, visit <unimplemented>"

# Complete! Post Message
/var/opt/github-drupal-deploy/github_pull_comment.sh -a "unb-libraries/build-profile-$URI_STRING" -i "$GITHUBPRID" -b "$BODYOFMESSAGE" <<< "$GITHUB_POST_MESSAGE_KEY"
