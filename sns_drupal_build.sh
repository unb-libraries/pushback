#!/usr/bin/env bash
set -e

while getopts “:b:t:u:s:” OPTION; do
  case $OPTION in
    b)
      BEGUN_BY=$OPTARG
      ;;
    t)
      TOPIC_ID=$OPTARG
      ;;
    u)
      JOB_URI=$OPTARG
      ;;
    s)
      MESSAGE_JOB_STATUS=$OPTARG
      ;;
  esac
done

if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

MESSAGE_SUBJECT="Build $MESSAGE_JOB_STATUS : $JOB_URI"
GITHUB_COMMIT_URI=`git log -n1 --pretty="https://github.com/unb-libraries/build-profile-${JOB_URI}/commit/%H"`
GITHUB_COMMIT_AUTHOR=`git log -n1 --pretty='%an (%ae)'`

MESSAGE_BODY="$MESSAGE_SUBJECT
Build Started By : $BEGUN_BY 
Last Committer : $GITHUB_COMMIT_AUTHOR
Commit URI : $GITHUB_COMMIT_URI
Log Available At : ${BUILD_URL}consoleText"

/var/opt/ec2-sns-sender/sns_send -t "$TOPIC_ID" -s "$MESSAGE_SUBJECT" -m "$MESSAGE_BODY"
