#!/bin/sh
set -e  # Exit on any error

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8283}"

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    until pg_isready -U "${POSTGRES_USER:-mirix}" -h localhost; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
    done
}

# Check if we're configured for external Postgres
if [ -n "$mirix_PG_URI" ]; then
    echo "External Postgres configuration detected, using $mirix_PG_URI"
else
    echo "No external Postgres configuration detected, starting internal PostgreSQL..."
    # Start PostgreSQL using the base image's entrypoint script
    /usr/local/bin/docker-entrypoint.sh postgres &

    # Wait for PostgreSQL to be ready
    wait_for_postgres

    # Set default connection URI for internal postgres
    export mirix_PG_URI="postgresql://${POSTGRES_USER:-mirix}:${POSTGRES_PASSWORD:-mirix}@localhost:5432/${POSTGRES_DB:-mirix}"
    echo "Using internal PostgreSQL at: $mirix_PG_URI"
fi

# Attempt database migration
echo "Attempting to migrate database..."
if ! alembic upgrade head; then
    echo "ERROR: Database migration failed!"
    echo "Please check your database connection and try again."
    echo "If the problem persists, check the logs for more details."
    exit 1
fi
echo "Database migration completed successfully."

# If ADE is enabled, add the --ade flag to the command
CMD="mirix server --host $HOST --port $PORT"
if [ "${SECURE:-false}" = "true" ]; then
    CMD="$CMD --secure"
fi

echo "Starting Mirix server at http://$HOST:$PORT..."
echo "Executing: $CMD"
exec $CMD
