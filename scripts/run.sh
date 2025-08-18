#!/bin/bash

# run locally
docker run  --name wraft-docs \
 --env-file scripts/.env.prod -it --rm -p 4000:4000 \
 --network wraft-net wraft-docs:latest