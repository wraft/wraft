#!/bin/bash

docker container run -it --rm -dp 4000:4000 --env-file .env --network wraft-net wraft-docs:latest
