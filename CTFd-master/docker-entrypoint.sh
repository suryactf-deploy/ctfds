#!/bin/bash
set -euo pipefail

# === Remove old SQLite database if it exists ===
SQLITE_DB="/opt/CTFd/CTFd/ctfd.db"
if [ -f "$SQLITE_DB" ]; then
    echo "[INFO] Removing existing SQLite database at $SQLITE_DB"
    rm -f "$SQLITE_DB"
fi

# === Set defaults for gunicorn ===
WORKERS=${WORKERS:-1}
WORKER_CLASS=${WORKER_CLASS:-gevent}
ACCESS_LOG=${ACCESS_LOG:--}
ERROR_LOG=${ERROR_LOG:--}
WORKER_TEMP_DIR=${WORKER_TEMP_DIR:-/dev/shm}
SECRET_KEY=${SECRET_KEY:-}
SKIP_DB_PING=${SKIP_DB_PING:-false}

# === Check SECRET_KEY for multi-worker setups ===
if [ ! -f .ctfd_secret_key ] && [ -z "$SECRET_KEY" ]; then
    if [ $WORKERS -gt 1 ]; then
        echo "[ ERROR ] You are configured to use more than 1 worker."
        echo "[ ERROR ] Define SECRET_KEY env variable or create a .ctfd_secret_key file."
        exit 1
    fi
fi

# === Ping database if SKIP_DB_PING is false ===
if [[ "$SKIP_DB_PING" == "false" ]]; then
  echo "[INFO] Checking database connection..."
  python ping.py
fi

# === Run database migrations (will use DATABASE_URL if set) ===
echo "[INFO] Running database migrations..."
flask db upgrade

# === Start CTFd with Gunicorn ===
echo "[INFO] Starting CTFd"
exec gunicorn 'CTFd:create_app()' \
    --bind '0.0.0.0:8000' \
    --workers $WORKERS \
    --worker-tmp-dir "$WORKER_TEMP_DIR" \
    --worker-class "$WORKER_CLASS" \
    --access-logfile "$ACCESS_LOG" \
    --error-logfile "$ERROR_LOG"
