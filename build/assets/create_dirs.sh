#!/bin/sh
if [ ! -d /assets/solr ]; then
  mkdir /assets/solr
  chown 8983:8983 /assets/solr
fi

if [ ! -d /assets/drupal ]; then
  mkdir /assets/drupal
  chown 33:33 /assets/drupal
fi

if [ ! -d /assets/mysql ]; then
  mkdir /assets/mysql
  chown 999:999 /assets/mysql
fi
