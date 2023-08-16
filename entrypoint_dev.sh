#!/bin/bash
# Docker entry point script.
# Wait until postgres is ready

while ! PGPASSWORD=$PGPASSWORD pg_isready -q -h $PGHOST -p $PGPORT -U $PGUSER
do
  echo "$(date) - [] Waiting for Database to start"
  sleep 2
done

echo "$(date) - [] PostgreSQL is ready"

if [[ -z `psql -Atqc "\\list $PGDATABASE"` ]]; then
  echo "Database $PGDATABASE does not exist. Creating..."
  createdb -E UTF8 $PGDATABASE -l en_US.UTF-8 -T template0
  mix ecto.migrate
  mix run priv/repo/seeds.exs
  echo "Database $PGDATABASE created."
fi

mix ecto.migrate
mix wraft.permissions
exec mix phx.server
