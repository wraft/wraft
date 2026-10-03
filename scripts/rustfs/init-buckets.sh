#!/bin/sh
set -eu

if [ "$S3_BACKUP_BUCKET" = "$S3_BUCKET" ]; then
  echo "S3_BACKUP_BUCKET must differ from S3_BUCKET; the app bucket is anonymously readable" >&2
  exit 1
fi

rc alias set wraft "$S3_URL" "$S3_ACCESS_KEY" "$S3_SECRET_KEY"

rc bucket create -p "wraft/$S3_BUCKET"
rc bucket anonymous set download "wraft/$S3_BUCKET"
rc bucket cors set "wraft/$S3_BUCKET" /init/cors.json

rc bucket create -p "wraft/$S3_BACKUP_BUCKET"
