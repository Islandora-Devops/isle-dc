docker exec -it -u 0 isle_dc_proto_php bash -c "mkdir -p /opt/keys/config"
docker cp ./private.key isle_dc_proto_php:/opt/keys
docker cp ./public.key isle_dc_proto_php:/opt/keys
docker cp ./key.key.islandora_rsa_key.yml isle_dc_proto_php:/opt/keys/config
docker cp ./jwt.config.yml isle_dc_proto_php:/opt/keys/config
