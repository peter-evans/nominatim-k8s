#!/bin/bash

set -ex

if [ "$NOMINATIM_MODE" != "CREATE" ] && [ "$NOMINATIM_MODE" != "RESTORE" ] && [ "$NOMINATIM_MODE" != "UPDATE" ]; then
    # Default to do nothing
    NOMINATIM_MODE=""
fi

# Defaults
NOMINATIM_DATA_PATH=${NOMINATIM_DATA_PATH:="/srv/nominatim/data"}
NOMINATIM_PG_THREADS=${NOMINATIM_PG_THREADS:=2}
NOMINATIM_PG_USER=${NOMINATIM_PG_USER:="nominatim"}
NOMINATIM_PG_PASSWORD=${NOMINATIM_PG_PASSWORD:="och5taere9hefohcohJe"}

NOMINATIM_PG_DSN=${NOMINATIM_PG_DSN:="pgsql:dbname=nominatim"}

if [ "$NOMINATIM_MODE" == "CREATE" ]; then
    # Variables
    PG_PASSWORD=$(echo -n ${NOMINATIM_PG_PASSWORD}${NOMINATIM_PG_USER} | md5sum | awk '{ print $1 }')

    # Start PostgreSQL
    service postgresql start

    # Import data
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres psql postgres -c "CREATE USER nominatim WITH SUPERUSER ENCRYPTED PASSWORD 'md5${PG_PASSWORD}'"
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim"

    # Allow user accounts read access to the data
    mkdir -p $NOMINATIM_DATA_PATH
    chmod 755 $NOMINATIM_DATA_PATH
    chown -R nominatim:nominatim $NOMINATIM_DATA_PATH

    sudo -E -u nominatim /srv/nominatim/build/utils/import_multiple_regions.sh

    service postgresql stop

elif [ "$NOMINATIM_MODE" == "UPDATE" ]; then

    echo "@define('CONST_Database_DSN', '${NOMINATIM_PG_DSN}');" >> /srv/nominatim/build/settings/local.php

    exec sudo -E -u nominatim /srv/nominatim/build/utils/update_multiple_regions.sh

fi

chown -R postgres:postgres /var/lib/postgresql/
chmod -R 0750 /var/lib/postgresql/

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
