#!/bin/sh

if [ -t 1 ] ; then
  docker-compose exec -T testcafe npm test
else
  docker-compose exec -ti testcafe npm test
fi
