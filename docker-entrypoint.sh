#!/bin/bash

if [ "$NOMINATIM_MODE" != "CREATE" ] && [ "$NOMINATIM_MODE" != "RESTORE" ]; then
    # Default to CREATE
    NOMINATIM_MODE="CREATE"
fi

# Defaults
NOMINATIM_DATA_PATH=${NOMINATIM_DATA_PATH:="/srv/nominatim/data"}
NOMINATIM_DATA_LABEL=${NOMINATIM_DATA_LABEL:="data"}
NOMINATIM_PBF_URL=${NOMINATIM_PBF_URL:="http://download.geofabrik.de/asia/maldives-latest.osm.pbf"}
NOMINATIM_POSTGRESQL_DATA_PATH=${NOMINATIM_POSTGRESQL_DATA_PATH:="/var/lib/postgresql/13/main"}
NOMINATIM_PG_THREADS=${NOMINATIM_PG_THREADS:=2}
NOMINATIM_PG_USER=${NOMINATIM_PG_USER:="nominatim"}
NOMINATIM_PG_PASSWORD=${NOMINATIM_PG_PASSWORD:="och5taere9hefohcohJe"}

# Variables
PG_PASSWORD=$(echo -n ${NOMINATIM_PG_PASSWORD}${NOMINATIM_PG_USER} | md5sum)

if [ "$NOMINATIM_MODE" == "CREATE" ]; then
    # Start PostgreSQL
    service postgresql start

    # Import data
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres psql postgres -c "CREATE USER nominatim WITH SUPERUSER PASSWORD '$PG_PASSWORD'"
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim"
    useradd -m -p $NOMINATIM_PG_PASSWORD nominatim

    # Retrieve the PBF file
    curl -L $NOMINATIM_PBF_URL --create-dirs -o $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf
    # Allow user accounts read access to the data
    chmod 755 $NOMINATIM_DATA_PATH

    sudo -u nominatim /srv/nominatim/build/utils/setup.php --osm-file $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf --all --threads $NOMINATIM_PG_THREADS

    service postgresql stop
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
