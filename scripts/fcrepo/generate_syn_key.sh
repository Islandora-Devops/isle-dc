#!/bin/bash
mkdir -p ../../syn-keys
openssl genrsa -out ../../syn-keys/syn_private.key 2048
openssl rsa -pubout -in ../../syn-keys/syn_private.key -out ../../syn-keys/syn_public.key
