#!/bin/bash

# create local build
exec ./scripts/build.sh

# create docker network
echo "Hi"

exec ./scripts/network.sh

# run db on the network
exec ./scripts/db-start.sh

# run app
exec ./scripts/start.sh
