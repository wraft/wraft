#!/bin/bash
# Docker entry point script.
# Wait until postgres is ready

# Check if required environment variables are set
if [[ -z "$DEV_DB_USERNAME" ]]; then
  echo "Error: DEV_DB_USERNAME environment variable is not set."
  exit 1
fi

if [[ -z "$DEV_DB_PASSWORD" ]]; then
  echo "Error: DEV_DB_PASSWORD environment variable is not set."
  exit 1
fi

if [[ -z "$DEV_DB_NAME" ]]; then
  echo "Error: DEV_DB_NAME environment variable is not set."
  exit 1
fi

# Set database connection parameters
DB_USER=$DEV_DB_USERNAME
DB_PASS=$DEV_DB_PASSWORD
DB_NAME=$DEV_DB_NAME
DB_HOST=${DEV_DB_HOST:-localhost}
DB_PORT=${DEV_DB_PORT:-5432}

while ! PGPASSWORD=$DB_PASS pg_isready -q -h $DB_HOST -p $DB_PORT -U $DB_USER
do
  echo "$(date) - [] Waiting for Database to start eedsd"
  sleep 2
done

echo "$(date) - [] PostgreSQL is ready"

if [[ -z `psql -Atqc "\\list $DB_NAME"` ]]; then
  echo "Database $DB_NAME does not exist. Creating..."
  createdb -E UTF8 $DB_NAME -l en_US.UTF-8 -T template0
  mix wraft.bucket
  mix ecto.migrate
  mix run priv/repo/seeds.exs
  echo "Database $DB_NAME created."
fi

mix ecto.migrate
mix wraft.permissions
exec mix phx.server