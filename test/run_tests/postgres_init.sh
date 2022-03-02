#!/bin/bash

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

set -e

#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#    CREATE USER docker;
#    CREATE DATABASE test_db;
#    GRANT ALL PRIVILEGES ON DATABASE test_db TO docker;
#EOSQL
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE test_db TO docker;
EOSQL
