#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER docker PASSWORD '$DOCKER_PSQL_PASS';
    CREATE DATABASE travis_ci_test;
    GRANT ALL PRIVILEGES ON DATABASE travis_ci_test TO docker;
EOSQL
