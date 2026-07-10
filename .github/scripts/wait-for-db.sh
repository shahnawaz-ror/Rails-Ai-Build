#!/usr/bin/env bash
set -euo pipefail

adapter="${TEST_DB_ADAPTER:-sqlite3}"
host="${TEST_DB_HOST:-127.0.0.1}"

if [[ "$adapter" == "postgresql" ]]; then
  port="${TEST_DB_PORT:-5432}"
  user="${TEST_DB_USER:-postgres}"
  export PGPASSWORD="${TEST_DB_PASSWORD:-postgres}"
  for _ in $(seq 1 30); do
    if pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; then
      echo "PostgreSQL is ready"
      exit 0
    fi
    sleep 2
  done
  echo "PostgreSQL did not become ready in time"
  exit 1
fi

if [[ "$adapter" == "mysql2" ]]; then
  port="${TEST_DB_PORT:-3306}"
  user="${TEST_DB_USER:-root}"
  password="${TEST_DB_PASSWORD:-root}"
  for _ in $(seq 1 30); do
    if mysqladmin ping -h "$host" -P "$port" -u"$user" -p"$password" --silent >/dev/null 2>&1; then
      echo "MySQL is ready"
      exit 0
    fi
    sleep 2
  done
  echo "MySQL did not become ready in time"
  exit 1
fi

echo "No wait needed for adapter=$adapter"
