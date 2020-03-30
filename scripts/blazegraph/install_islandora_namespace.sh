#!/bin/bash
echo "Installing Islandora namespace on Blazegraph"
curl -X POST -H "Content-Type: text/plain" --data-binary @/RWStore.properties http://localhost:8080/blazegraph/namespace
# If this worked correctly, Blazegraph should respond with "CREATED: islandora"
# to let us know it created the islandora namespace.
curl -X POST -H "Content-Type: text/plain" --data-binary @/inference.nt http://localhost:8080/blazegraph/namespace/islandora/sparql
# If this worked correctly, Blazegraph should respond with some XML letting us
# know it added the 2 entries from inference.nt to the namespace.
exit