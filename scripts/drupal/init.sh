#!/usr/bin/env bash

set -e

# Print the number of arguments.
# echo "$#"

codebase="drupal"
config_dir="$PWD/config/drupal"
scripts_dir="$PWD/scripts/drupal"

function fail {
  echo -e "\033[31m[ERROR]\033[0m $1" >&2
  exit 1
}

function help() {
  echo "This command create the codebase folder using composer create-project based on drupal/recommended-project or islandora/drupal-project"
  echo " "
  echo "options:"
  echo "-h, --help                 show brief help"
  echo "-c, --codebase CODEBASE    specify a codebase to use. drupal or islandora are the valid option"
  exit 0
}

function install_drupal() {
  local composer=$(command -v composer)
  local args="create-project drupal/recommended-project:^8.8 codebase"
  local flags="--ignore-platform-reqs --no-interaction"
  local codebase="$1"
  local drush_require="require drush/drush $flags"

  if [[ "$codebase" == "islandora" ]]; then
    local args="create-project islandora/drupal-project codebase"
  fi

  echo -e "\033[1m[INFO]\033[0m Installing drupal using composer"
  echo " "
  if [[ composer ]]; then
    echo "       You have composer installed locally and we are using it to download the drupal project."
    echo >&2
    $composer $args $flags
    echo "       Adding drush to the drupal repository."
    echo >&2
    cd codebase && $composer $drush_require && cd ..
  elif [[ ! composer ]]; then
    echo "       Using the official composer docker image to download drupal."
    mkdir -p $HOME/.composer && docker container run -it --rm -v $HOME/.composer:/tmp -v $PWD:/app composer:1.9.3 $composer_cmd_arguments $composer_cmd_flags
    echo "       Adding drush to the drupal repository."
    echo >&2
    cd codebase && docker container run -it --rm -v $HOME/.composer:/tmp -v $PWD:/app composer:1.9.3 $drush_require && cd ..
  else
    fail "We could not download drupal. Please check your arguments and try again."
  fi
}

function setup_settings_isle_php() {
  local default_dir="$PWD/codebase/web/sites/default"
  local settings="${default_dir}/settings.php"
  local settings_default="${default_dir}/default.settings.php"
  local settings_isle="settings.isle.php"
  local insert_after="\$settings\[\'entity_update_backup\'\] \= TRUE\;"
  local snippet="${config_dir}/snippet.txt"

  if [[ -f "${default_dir}/${settings_isle}" ]]; then
    fail "An existing settings.isle.php was found under ${default_dir}."
  fi

  echo -e "\033[1m[INFO]\033[0m Setting up settings.isle.php to be included in settings.php"
  echo " "
  if [[ ! -f "${settings}" ]]; then
    echo "       An existing settings.php file couldn't be located and one is created from default.settings.php."
    cp ${settings_default} ${settings}
  else
    echo "       An existing settings.php file was found."
  fi

  sed -i '' -e "/${insert_after}/r ${snippet}" ${settings}
  cp "${config_dir}/${settings_isle}" "${default_dir}/${settings_isle}"
  echo "       settings.isle.php was successfully setup ."
  echo >&2
}

while [ ! $# -eq 0 ]
do
  case "$1" in
    --help | -h)
      help
      exit
      ;;
    --debug | -d)
      set -x
      ;;
    --codebase | -c)
      shift
      codebase=$1
      if [[ "$codebase" != 'drupal' && "$codebase" != 'islandora' ]]; then
        fail "codebase:$codebase is unsupported. Only vanilla drupal or islandora can be downloaded."
      fi
      ;;
  esac
  shift
done

# Checking if the codebase directory exists and quit.
if [[ -d "$PWD/codebase" && "$(ls -A $PWD/codebase)" ]]; then
  fail "The codebase directory exists and is not empty. Please delete it and run this command again."
fi

# Initialize drupal database and files persistent storage folders.
mkdir -p $PWD/data/drupal/files/public $PWD/data/drupal/files/private $PWD/data/drupal/database

install_drupal $codebase
setup_settings_isle_php
