#!/usr/bin/env bash

set -e

keys_dir="$PWD/data/jwt"

if [[ ! -d $keys_dir ]]; then
  echo "Creating $keys_dir"
  mkdir -p "$keys_dir"
else
  echo "$keys_dir already exists, no need to create it."
fi

if [[ ! -f $keys_dir/private.key ]]; then
  echo "Generating private key"
  openssl genrsa -out "$keys_dir/private.key" 2048
else
  echo "$keys_dir/private.key already exists. Skipping..."
fi

if [[ ! -f $keys_dir/public.key ]]; then
  echo "Generating public key"
  openssl rsa -pubout -in "$keys_dir/private.key" -out "$keys_dir/public.key"
else
  echo "$keys_dir/public.key already exists. Skipping..."
fi
