#!/bin/bash

docker container run -it \
 --name wraft-docs \
 --rm -dp 4000:4000 --env-file scripts/.env.prod \
 --network wraft-net wraft-docs:latest
