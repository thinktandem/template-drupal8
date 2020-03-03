#!/bin/bash
set -e

# TODO: how do we handle a borked setup? eg delete the project before exiting?
# TODO: get a separate script for a lando pull command to get databases and mounts
# Use the platform.sh CLI to export your database
#cd /path/to/repo/root
#lando platform db:dump --gzip --file=dump.sql.gz --project=PROJECT_ID --environment=master

# Import the DB with Lando
#lando db-import dump.sql.gz

# Remove the DB dump to be safe
#rm -f dump.sql.gz

# HELPFUL ENVARS
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOCKFILE="$DIR/../setup.lock"
PATH="$PATH:/var/www/.platformsh/bin"

# DEFAULTS
PLATFORM_TOKEN_VALIDATOR="none"
PLATFORM_USER="none"
YES=

# INCLUDE MESSAGING HELPERS
source "$DIR/messages.sh"

# PARSE THE ARGZZ
while (( "$#" )); do
  case "$1" in
    --github-token|--github-token=*)
      if [ "${1##--github-token=}" != "$1" ]; then
        GITHUB_TOKEN="${1##--github-token=}"
        shift
      else
        GITHUB_TOKEN=$2
        shift 2
      fi
      ;;
    --github-slug|--github-slug=*)
      if [ "${1##--github-slug=}" != "$1" ]; then
        GITHUB_SLUG="${1##--github-slug=}"
        shift
      else
        GITHUB_SLUG=$2
        shift 2
      fi
      ;;
    --name|--name=*)
      if [ "${1##--name=}" != "$1" ]; then
        PLATFORM_NAME="${1##--name=}"
        shift
      else
        PLATFORM_NAME=$2
        shift 2
      fi
      ;;
    --plan|--plan=*)
      if [ "${1##--plan=}" != "$1" ]; then
        PLATFORM_PLAN="${1##--plan=}"
        shift
      else
        PLATFORM_PLAN=$2
        shift 2
      fi
      ;;
    --region|--region=*)
      if [ "${1##--region=}" != "$1" ]; then
        PLATFORM_REGION="${1##--region=}"
        shift
      else
        PLATFORM_REGION=$2
        shift 2
      fi
      ;;
    --supreme-leader-token|--supreme-leader-token=*)
      if [ "${1##--supreme-leader-token=}" != "$1" ]; then
        export PLATFORMSH_CLI_TOKEN="${1##--supreme-leader-token=}"
        shift
      else
        export PLATFORMSH_CLI_TOKEN=$2
        shift 2
      fi
      ;;
    --supreme-leader-validator|--supreme-leader-validator=*)
      if [ "${1##--supreme-leader-validator=}" != "$1" ]; then
        PLATFORM_TOKEN_VALIDATOR="${1##--supreme-leader-validator=}"
        shift
      else
        PLATFORM_TOKEN_VALIDATOR=$2
        shift 2
      fi
      ;;
    --user|--user=*)
      if [ "${1##--user=}" != "$1" ]; then
        PLATFORM_USER="${1##--user=}"
        shift
      else
        PLATFORM_USER=$2
        shift 2
      fi
      ;;
    --force|--force=*)
        rm -rf $LOCKFILE
        shift
      ;;
    -y|--yes)
        YES="--yes"
        shift
      ;;
    --)
      shift
      break
      ;;
    -*|--*=)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# PLATFORM TOKEN IS BAD
bad_platform_token() {
  status_warn "This does not appear to be a valid Platform.sh token!"
  error "Visit https://docs.platform.sh/gettingstarted/cli/api-tokens.html, create a new token and then try agan"
}

# VALIDATE PLATFORM TOKEN
validate_platform_token() {
  # Make sure we logout first
  platform logout
  if ! platform auth:info; then
    bad_platform_token
  fi
  # Validate the user is correct if we can
  if [ "$PLATFORM_TOKEN_VALIDATOR" != "none" ]; then
    if ! platform auth:info --no-header --property=mail | grep $PLATFORM_TOKEN_VALIDATOR; then
      bad_platform_token
    fi
  fi
}

# VALIDATE GH TOKEN
validate_gh_token() {
  if ! curl -i -f -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user; then
    status_warn "This does not appear to be a valid GitHub token!"
    error "Visit https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line\n\
      amd create a new token with 'repo' and 'admin:repo_hook' grants and then try again"
  fi
}

# This is where the main logic starts
if [ -f "$LOCKFILE" ]; then
  status_warn "Looks like setup has already been run"
  status_warn "If you REALLY want to run setup then try it again with --force"
  echo ""
  error "Abort! abort!! abort!!!"
fi;

# Kick it off
print_setup

# Validate the platform token
echo "Validating your supreme-leadertoken..."
validate_platform_token
status_good "Your supreme-leader token appears to be valid!\n"

# Validate the github token generally
echo "Validating your GitHub token..."
validate_gh_token
status_good "Your GitHub token appears to be valid!\n"

# Tell the user what we are going to try to do
echo -e "About to provision the following platform.sh project...\n"
echo "NAME: $PLATFORM_NAME"
echo "REGION: $PLATFORM_REGION"
echo "PLAN: $PLATFORM_PLAN"
echo "GITHUB UPSTREAM: $GITHUB_SLUG"
echo "ADD USER: $PLATFORM_USER"
echo "OWNER: $PLATFORM_TOKEN_VALIDATOR"

# Making sure that site doesnt already exist
echo "Making sure that site doesn't already exist..."
if platform projects --title="$PLATFORM_NAME" --pipe | wc -l | grep 0 >/dev/null; then
  # Kick it
  status_good "$PLATFORM_NAME doesn't exist!"

  # Spin up the platform site
  echo "Creating it..."
  platform create \
    --title "$PLATFORM_NAME" \
    --region "$PLATFORM_REGION" \
    --plan "$PLATFORM_PLAN" \
    --environments 3 \
    --storage 5 \
    $YES

  # Get and print hte new id
  PLATFORM_PROJECT=$(platform projects --title="$PLATFORM_NAME" --pipe)
  status_good "Your new project id is $PLATFORM_PROJECT"

  # Add a bonus user if specified
  if [ "$PLATFORM_USER" != "none" ]; then
    echo "Adding $PLATFORM_USER..."
    platform user:add $PLATFORM_USER --role=admin --project=$PLATFORM_PROJECT $YES
  fi
  status_good "Added user to $PLATFORM_NAME"

  # Add the GitHub integration
  echo "Adding the GitHub integration..."
  platform integration:add \
    --type=github \
    --project=$PLATFORM_PROJECT \
    --token=$GITHUB_TOKEN \
    --repository=$GITHUB_SLUG \
    --build-pull-requests=true \
    --build-pull-requests-post-merge=false \
    --pull-requests-clone-parent-data=true \
    --resync-pull-requests=false \
    --fetch-branches=true \
    --prune-branches=false \
    $YES
  status_good "$PLATFORM_NAME is now tracking $GITHUB_SLUG"

else
  error "$PLATFORM_NAME already exists! Exiting..."
fi

# Lock the setup
touch $LOCKFILE
status_good "$PLATFORM_NAME is now ready with all the DevOps!"
