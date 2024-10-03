#!/bin/bash
# Docker entry point script.
# Wait until postgres is ready

# Check if necessary environment variables are set
if [[ -z "$DEV_DB_PASSWORD" || -z "$DEV_DB_HOST" || -z "$DEV_DB_PORT" || -z "$DEV_DB_USERNAME" ]]; then
  echo "Error: Required environment variables (PGPASSWORD, PGHOST, PGPORT, PGUSER) are not set."
  exit 1
fi

while ! PGPASSWORD=$DEV_DB_PASSWORD pg_isready -q -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USERNAME
do
  echo "$(date) - [] Waiting for Database to start eedsd"
  sleep 2
done

echo "$(date) - [] PostgreSQL is ready"

if [[ -z `psql -Atqc "\\list $DEV_DB_NAME"` ]]; then
  echo "Database $DEV_DB_NAME does not exist. Creating..."
  createdb -E UTF8 $DEV_DB_NAME -l en_US.UTF-8 -T template0
  mix ecto.migrate
  mix run priv/repo/seeds.exs
  echo "Database $DEV_DB_NAME created."
fi

mix ecto.migrate
mix wraft.permissions
exec mix phx.server
