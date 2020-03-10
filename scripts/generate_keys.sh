#!/bin/bash

openssl genrsa -out ../jwt/private.key 2048
openssl rsa -pubout -in ../jwt/private.key -out ../jwt/public.key
