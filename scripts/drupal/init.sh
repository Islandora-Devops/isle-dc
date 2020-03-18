#!/usr/bin/env bash

set -e

# Print the number of arguments.
# echo "$#"

codebase="drupal"
config_dir="$PWD/config/drupal"
scripts_dir="$PWD/scripts/drupal"
composer_install_run="true"
current_folder="$PWD"
composer_general_flags="--ignore-platform-reqs --no-interaction"
OS=`uname -s`
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
  local args="create-project drupal/recommended-project:^8.8"
  local flags="--ignore-platform-reqs --no-interaction"
  local codebase="$1"
  local drush_require="require drush/drush $flags"

  if [[ ! $composer ]]; then
    fail "We could not download drupal. Ensure composer or docker is setup and installed properly on your local host."
  fi

  if [[ "$codebase" == "islandora" ]]; then
    local args="create-project islandora/drupal-project"
  fi

  echo -e "\033[1m[INFO]\033[0m Installing drupal using composer"
  echo " "

  echo "       Downloading the drupal codebase."
  echo >&2
  cd "$current_folder/"
  $composer $args $composer_general_flags codebase

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
      sed -i '' -e '\|^'"$pattern"'|i\'$'\n'"$snippet" composer.json
    else
      local snippet="\    \"autoload\": {\n       \"files\": [\"load\.environment\.php\"]\n    },\n"
      sed -i -e "/^${pattern}/i ${snippet}" composer.json
    fi
  fi

  for i in "${!packages[@]}"; do
    local package=${packages[$i]}
    local version=${versions[$i]}
    # Only installing a package when it is not available in composer.json
    if [[ ! $(grep "${package}" composer.json) ]]; then
      echo "       Requiring ${package}. Skipping."
      $composer require ${package}:${version} $composer_general_flags
    else
      echo "       ${package} was found in the composer.json. Skipping."
    fi
  done
  echo " "
  echo >&2

  # Flag that we shouldn't run composer install to initialize everything.
  composer_install_run="false"
  cd "$current_folder"
}

function create_required_files() {
  local drupal_root="$current_folder/codebase/web"
  local default_dir="$drupal_root/sites/default"
  local settings="${default_dir}/settings.php"
  local settings_default="${default_dir}/default.settings.php"
  local settings_isle="settings.isle.php"
  local insert_after="\$settings\[\'entity_update_backup\'\] \= TRUE\;"
  local config_sync_pattern="\$settings\['config_sync_directory'] = '\/directory\/outside\/webroot'"
  local snippet="${config_dir}/snippet.txt"

  # Prepare the settings file for installation. In case the user has an existing
  # one we skip overriding it.
  if [[ ! -f "${settings}" && -f "${settings_default}" ]]; then
    cp ${settings_default} ${settings}
  fi

  # Ensuring that settings.php is pointing to the proper config_sync_directory.
  if [[ $(grep "^#.* ${config_sync_pattern}" ${settings} || true) ]]; then
    local replace="\$settings\['config_sync_directory'] = '..\/config\/sync'"
    if $is_darwin; then
      sed -i '' -e "s/^#.* ${config_sync_pattern}/${replace}/" ${settings}
    else
      sed -i -e "s/^#.* ${config_sync_pattern}/${replace}/" ${settings}
    fi
  fi

  # Insert settings.isle.php snippet into the settings.php file
  if [[ ! -f "${default_dir}/${settings_isle}" ]]; then
    echo -e "\033[1m[INFO]\033[0m Setting up settings.isle.php to be included in settings.php"
    echo " "
    if $is_darwin; then
      sed -i '' -e "/${insert_after}/r ${snippet}" ${settings}
    else
      sed -i -e "/${insert_after}/r ${snippet}" ${settings}
    fi
    cp "${config_dir}/${settings_isle}" "${default_dir}/${settings_isle}"
    echo "       settings.isle.php was successfully setup."
    echo >&2
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
# Determine how we will be running composer.
###
composer=$(command -v composer || true)
if [[ ! $composer ]]; then
  # We use the docker composer image to run composer related commands.
  echo >&2
  echo -e "\033[1m[INFO]\033[0m Using the official composer docker image to run composer commands"
  echo " "
  echo >&2
  mkdir -p ~/.composer
  composer="docker container run -it --rm -v ~/.composer:/tmp -v $PWD:/app composer:1.9.3"
fi

###
# Checking if the project code exists.
###
if [[ ! -f "$PWD/codebase/composer.json" ]]; then
  download_drupal $codebase
else
  download_required_packages
fi

###
# Initialize drupal database and files persistent storage folders.
###
mkdir -p $PWD/data/drupal/files/public $PWD/data/drupal/files/private $PWD/data/drupal/database

###
# Running composer install just in case the user has an existing project.
###
if [[ "$composer_install_run" == "true" ]]; then
  cd "$current_folder/codebase"
  $composer install $composer_flags
  cd ..
fi

###
# Create required files if this init was called for an existing project/codebase.
###
if [[ ! -f "$current_folder/codebase/web/sites/default/settings.isle.php" ]]; then
  create_required_files
fi
