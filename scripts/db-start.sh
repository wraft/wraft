#!/bin/bash

echo " Run a vanilla postgres datbase with custom network "

# create a local networking to establish connections
docker network create --driver bridge wraft-net

docker run --name wraft-db \
  --network wraft-net \
  --rm \
  -p 5432:5432 \
  --network-alias wraft-pghost \
  -e POSTGRES_PASSWORD=passwordless \
  -d postgres:latest
