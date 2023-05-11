#!/usr/bin/env bash
set -e

# This script is meant to only be called via the Makefile not independently.

function generate_jwt_keys() {
	openssl genrsa -out /tmp/private.key 2048 &>/dev/null
	openssl rsa -pubout -in /tmp/private.key -out /tmp/public.key &>/dev/null
}

function random_secret() {
	local characters=${1}
	local size=${2}
	local name=${3}
	tr -dc "${characters}" </dev/urandom | head -c "${size}" >/secrets/live/"${name}"
}

function main() {
	echo "Generating Secrets"
	local secret_templates=($(find ../secrets/template/* -exec basename {} \;))
	generate_jwt_keys
	for secret in "${secret_templates[@]}"; do
		case "${secret}" in
		DRUPAL_DEFAULT_CONFIGDIR)
			cp /secrets/template/DRUPAL_DEFAULT_CONFIGDIR /secrets/live/DRUPAL_DEFAULT_CONFIGDIR
			;;
		DRUPAL_DEFAULT_SALT)
			random_secret 'A-Za-z0-9-_' 74 DRUPAL_DEFAULT_SALT
			;;
		JWT_ADMIN_TOKEN)
			random_secret 'A-Za-z0-9' 64 JWT_ADMIN_TOKEN
			;;
		JWT_PRIVATE_KEY)
			cp /tmp/private.key /secrets/live/JWT_PRIVATE_KEY
			;;
		JWT_PUBLIC_KEY)
			cp /tmp/public.key /secrets/live/JWT_PUBLIC_KEY
			;;
		*)
			random_secret 'A-Za-z0-9' 48 "${secret}"
			;;
		esac
		echo "Generated or copied ${secret}!"
	done
	# Make sure they are only readable by their owner.
	chmod 600 /secrets/live/*
}
main
