#!/bin/sh

GIT_TAG=$(git describe --tags --always)

for image_uri in $(cat docker-compose.yml | grep ghcr | awk '{print $2}'); do
	image_name=$(echo ${image_uri} | tr ':' ' ' | awk '{print $1}' | awk -F "/" '{print $NF}')
	echo $image_name

	dest_url=${DOCKER_PUSH_REPOSITORY}/${image_name}:${GIT_TAG}

	docker tag $image_uri $dest_url
	docker push $dest_url
done
