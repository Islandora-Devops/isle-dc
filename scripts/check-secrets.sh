#!/usr/bin/env bash
set -e

RED=$(tput -Txterm setaf 1)
GREEN=$(tput -Txterm setaf 2)
YELLOW=$(tput -Txterm setaf 3)
BLUE=$(tput -Txterm setaf 4)
RESET=$(tput -Txterm sgr0)
TARGET_MAX_CHAR_NUM=20

source .env || {
  echo "${RED}ERROR: .env file not found.${RESET}"
  exit 1
}
FOUND_INSECURE_SECRETS=false

function print_security_warning() {
	if [ "${FOUND_INSECURE_SECRETS}" == true ]; then
cat << EOF


	${YELLOW} --- --- WARNING --- --- ${RESET}${RED} --- --- WARNING --- --- ${RESET}

	${RED}
		Using default values for secrets in a production environment is a

					Security Risk${RESET}
		
		Default values are identified in ${GREEN}$(pwd)/secrets/live/${RESET}

		If you are using the default values, you can either change the values of 
		the file found in $(pwd)/secrets/live/ 
		Or generate new secrets by running:
			${GREEN}make generate-secrets ${RESET}

		This will generate new secrets in /secrets/live/ but will not update
		the ISLE containers.
		
		If you are not sure how to push updated secrets to ISLE, please consult
		the documentation.${BLUE}
		https://islandora.github.io/documentation/installation/docker-custom/#secrets
	${RESET}

	${YELLOW} --- --- WARNING --- --- ${RESET}${RED} --- --- WARNING --- --- ${RESET}


EOF
	fi
}

function main() {
	unameOut="$(uname -s)"
	case "${unameOut}" in
		Linux*)     hash=sha1sum;;
		Darwin*)    hash=md5;;
		*)          hash="UNKNOWN"
	esac
	# Check if $USE_SECRETS is set to true.
	if [ "$USE_SECRETS" = true ]; then
		local secret_live=[];
		# Check if the $(pwd)/secrets/live directory is empty.
		if [ "$(ls -I ".keep" $(pwd)/secrets/live)" ]; then
			local secret_live=($(find $(pwd)/secrets/live/* -exec basename {} \;))
		fi
	fi

	local secret_templates=($(find $(pwd)/secrets/template/* -exec basename {} \;))

	if [ ! "$(ls $(pwd)/secrets/live)" ]; then
		echo -e "\n${YELLOW}Checking secrets...${RESET}"
		echo "  No secrets found in $(pwd)/secrets/live/"
		echo -e "\nThere are 2 basic methods to create secrets:"
		echo " [1] - Generate new secrets via a script"
		echo -e " [2] - Copy secrets from a $(pwd)/secrets/template directory into $(pwd)/secrets/live/ and then modify them\n"
		echo -n "Would you like to generate random secrets? Run a script to create secrets? [y/N] "
		read ans
		if [[ ${ans} == [yY] ]] ; then
			docker run --rm -t \
			-v $(pwd)/secrets:/secrets \
			-v $(pwd)/scripts/generate-secrets.sh:/generate-secrets.sh \
			-w / \
			--entrypoint bash \
			${REPOSITORY}/drupal:${TAG} -c "/generate-secrets.sh && chown -R `id -u`:`id -g` /secrets"
			echo -e "\n${GREEN}Secrets generated.${RESET}"
		else
			echo ""
			echo -n "Would you like to copy the default secrets? Run a script to copy secrets? [y/N] " && \
			read second_ans
			if [[ ${second_ans:-N} == [yY] ]] ; then
				echo -e "\nCopying secrets from $(pwd)/secrets/template/ to $(pwd)/secrets/live/\n"
				echo -e "${GREEN}Suggestion${RESET}:\n    It is much easier to modify these before you start isle than to try to figure out how to push them to the containers."
				cp -n $(pwd)/secrets/template/* $(pwd)/secrets/live/
				echo -e "\n${RED}Exiting build${RESET}: Please modify the secrets in $(pwd)/secrets/live/ and then run the same ${BLUE}make${RESET} command again."
				echo -e "This is optional, but it is recommended to modify the secrets in $(pwd)/secrets/live/ before running on a production environment.\n\n"
				exit 1
			fi
		fi
	fi

	local secret_live=($(find $(pwd)/secrets/live/* -exec basename {} \;))
	for secret in "${secret_templates[@]}"; do
		if [[ ! "${secret_live[@]}" =~ "${secret}" ]]; then
			missing_secret_identified=true
			break;
		fi

		if [[ $hash == "UNKNOWN" ]]; then
			if [[ $(cat secrets/template/ACTIVEMQ_PASSWORD) == $(cat secrets/live/ACTIVEMQ_PASSWORD) ]]; then
				# Ignore the config location directory. This won't pose a security risk.
				if [[ ! "${secret}" = "DRUPAL_DEFAULT_CONFIGDIR" ]]; then
					echo -e "${RED}Default Secret${RESET} ${BLUE}->${RESET} $(pwd)/secrets/live/${secret}"
					FOUND_INSECURE_SECRETS=true
				fi
			fi
		else
			if [[ "$($hash $(pwd)/secrets/template/${secret}| awk '{print $1}')" == "$($hash $(pwd)/secrets/live/${secret}| awk '{print $1}')" ]]; then
				# Ignore the config location directory. This won't pose a security risk.
				if [[ ! "${secret}" = "DRUPAL_DEFAULT_CONFIGDIR" ]]; then
					echo -e "${RED}Default Secret${RESET} ${BLUE}->${RESET} $(pwd)/secrets/live/${secret}"
					FOUND_INSECURE_SECRETS=true
				fi
			fi
		fi
	done

	if [ "${missing_secret_identified}" = true ]; then
		echo -e "\n\nIdentified a few missing SECRETS.\n"
		echo -e "   Would you like to copy the missing secrets from $(pwd)/secrets/template/? [y/N] "
		read thr_ans
		if [[ ${thr_ans} == [yY] ]] ; then
			echo ""
			for secret in "${secret_templates[@]}"; do
				if [[ ! "${secret_live[@]}" =~ "${secret}" ]]; then
					echo "MISSING: $(pwd)/secrets/live/${secret}"
					echo -e "   Copying ${RED}${secret}${RESET} to $(pwd)/secrets/live/${GREEN}${secret}${RESET}\n"
					cp -n $(pwd)/secrets/template/${secret} $(pwd)/secrets/live/${secret}
					echo ""
				fi
			done
		else
			echo -e "\nPlease update the missing secrets before continuing.\n\n"
			exit 1
		fi
	fi
}

# Just incase the wishes to automate generation of secrets.
if [[ $1 == 'yes' ]]; then
	docker run --rm -t \
	-v $(pwd)/secrets:/secrets \
	-v $(pwd)/scripts/generate-secrets.sh:/generate-secrets.sh \
	-w / \
	--entrypoint bash \
	${REPOSITORY}/drupal:${TAG} -c "/generate-secrets.sh && chown -R `id -u`:`id -g` /secrets"
	echo -e "\n${GREEN}Secrets generated.${RESET}"
fi

main
print_security_warning