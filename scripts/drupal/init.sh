#!/usr/bin/env bash

set -euo pipefail

codebase="drupal"
config_dir="$PWD/config/drupal"
current_folder="$PWD"
composer_general_flags="--ignore-platform-reqs --no-interaction"
OS=$(uname -s)
[[ "$OS" == "Darwin" ]] && is_darwin=true || is_darwin=false

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

function download_drupal() {
  local args="create-project born-digital/drupal-project:dev-isle8-dev"
  local codebase="$1"

  # if [[ ! $composer ]]; then
  #   fail "We could not download drupal. Ensure composer or docker is setup and installed properly on your local host."
  # fi

  if [[ "$codebase" == "drupal" ]]; then
    local args="create-project drupal-composer/drupal-project:8.x-dev"
  fi

  echo -e "\033[1m[INFO]\033[0m Installing drupal using composer"
  echo " "

  echo "       Downloading the drupal codebase."
  echo >&2
  cd "$current_folder/"

  # Delete codebase just in case a previous command failed to finish the installation.
  [[ -d ./codebase ]] && rm -rf ./codebase
  composer_cmd "$args" "$composer_general_flags" codebase

  download_required_packages
}

function download_required_packages() {
  # Using two arrays cause the default MacOS bash is an older version. Probably less than 4.
  local packages=("zaporylie/composer-drupal-optimizations" "vlucas/phpdotenv" "drush/drush" "cweagans/composer-patches")
  local versions=("^1.1 --dev" "^4.0" "^10.0" "^1.6.7")

  echo -e "\033[1m[INFO]\033[0m Adding necessary packages to the drupal repository."
  echo " "
  echo >&2

  cd "$current_folder/codebase"

  # For vlucas/phpdotenv we need the load.environment.php script to be available.
  if [[ ! -f ./load.environment.php ]]; then
    cp "$current_folder/config/drupal/load.environment.php" .
    # Update the composer.json to include it.
    local pattern="    \"extra\""
    if $is_darwin; then
      local snippet=$'\    "autoload": {"files": ["load.environment.php"]},\n'
      sed -i '' -e '\|^'"$pattern"'|i'\'''$'\n'"$snippet" composer.json
    else
      local snippet="\    \"autoload\": {\n       \"files\": [\"load\.environment\.php\"]\n    },\n"
      sed -i -e "/^${pattern}/i ${snippet}" composer.json
    fi
  fi

  for i in "${!packages[@]}"; do
    local package=${packages[$i]}
    local version=${versions[$i]}
    # Only installing a package when it is not available in composer.json
    if ! grep -q "${package}" composer.json; then
      echo "       Requiring ${package}. Downloading."
      echo " "
      composer_cmd require "${package}":"${version}" "$composer_general_flags"
    else
      echo "       ${package} was found in the composer.json. Skipping."
    fi
  done
  echo " "
  echo >&2

  cd "$current_folder"
}

function create_required_files() {
  local drupal_root="$current_folder/codebase/web"
  local default_dir="$drupal_root/sites/default"
  local settings="${default_dir}/settings.php"
  local settings_project="settings.project.php"

  # Insert settings.isle.php snippet into the settings.php file
  if [[ ! -f "${default_dir}/${settings_project}" ]]; then
    echo " "
    echo -e "\033[1m[INFO]\033[0m Adjusting settings.php to work with the Isle dc."
    echo "       If there is any customization made to the current settings.php, they will need to be moved manually."

    # Let make a backup of an existing settings.php if found
    if [[ -f "${settings}" ]]; then
      mv "${settings}" "${settings}.bak"
      echo "       An existing settings.php was found and it was renamed to ${settings}.bak."
    fi
    # Copying the settings with Isle customization in place.
    cp "${config_dir}/settings.php" "${settings}"
    cp "${config_dir}/${settings_project}" "${default_dir}/${settings_project}"
    echo " "
  fi
}

function composer_cmd() {
  ###
  # Determine how we will be running composer.
  ###
  if [[ ! $(command -v composer || true) ]]; then
    # We use the docker composer image to run composer related commands.
    echo >&2
    echo -e "\033[1m[INFO]\033[0m Using the official composer docker image to run composer commands"
    echo " "
    echo >&2
    mkdir -p "$HOME"/.composer
    if $is_darwin; then
      # shellcheck disable=SC2068
      docker container run -it --rm --user $UID:"$GUID" -v "$HOME"/.composer:/tmp -v "$PWD":/app composer:1.9.3 $@
    else
      # shellcheck disable=SC2068
      env MSYS_NO_PATHCONV=1 docker container run -t --rm --user $UID:"$GUID" -v "$HOME"/.composer:/tmp -v "$PWD":/app composer:1.9.3 $@
    fi
  else
    echo >&2
    echo -e "\033[1m[INFO]\033[0m Using local composer to run the commands"
    echo " "
    echo >&2
    # shellcheck disable=SC2068
    composer $@
  fi
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

###
# Checking if the project code exists.
###
if [[ ! -f "$current_folder/codebase/composer.json" ]]; then
  download_drupal "$codebase"
else
  download_required_packages
fi

# load the config here
if [[ "$codebase" == "islandora" && ! -f codebase/config/sync/core.extension.yml ]]; then
  tar -xzf config/drupal/islandora-starter-config.tar.gz codebase/config/sync
fi

###
# Initialize drupal files persistent storage folders.
###
mkdir -p "$PWD"/data/drupal/files/public "$PWD"/data/drupal/files/private

###
# Running composer install just in case the user has an existing project.
###
if [[ ! -f "$current_folder/codebase/vendor/autoload.php" ]]; then
  cd "$current_folder/codebase"
  echo >&2
  echo -e "\033[1m[INFO]\033[0m Running composer install just in case the user has an existing project"
  echo " "
  echo >&2

  composer_cmd install "$composer_general_flags"
  cd ..
fi

###
# Create required files if this init was called for an existing project/codebase.
###
if [[ ! -f "$current_folder/codebase/web/sites/default/settings.isle.php" ]]; then
  create_required_files
fi
