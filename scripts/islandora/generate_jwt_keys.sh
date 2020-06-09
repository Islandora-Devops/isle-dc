#!/bin/bash

chmod 775 /opt/keys/claw
openssl genrsa -out /opt/keys/claw/private.key 2048
openssl rsa -pubout -in /opt/keys/claw/private.key -out /opt/keys/claw/public.key