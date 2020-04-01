#!/bin/bash

env MSYS_NO_PATHCONV=1 docker-compose -p islandora exec -T solr /opt/solr/bin/solr create -c islandora
