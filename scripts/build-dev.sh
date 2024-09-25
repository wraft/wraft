#!/bin/bash

SECRET_KEY_BASE=
DATABASE_URL=
PORT=4000
echo " Building Image with  ${DATABASE_URL} \ ${SECRET_KEY_BASE}"

docker build \
-f Dockerfile.dev \
--build-arg SECRET_KEY_BASE=${SECRET_KEY_BASE} \
--build-arg DATABASE_URL=${DATABASE_URL} \
--build-arg PORT=${PORT} \
--build-arg RELEASE_NAME=wraft_doc_dev \
 -t wraft-docs:latest .
