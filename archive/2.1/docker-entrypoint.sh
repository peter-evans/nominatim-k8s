#!/bin/bash

if [ "$NOMINATIM_MODE" != "CREATE" ] && [ "$NOMINATIM_MODE" != "RESTORE" ]; then
    # Default to CREATE
    NOMINATIM_MODE="CREATE"
fi

# Defaults
NOMINATIM_DATA_PATH=${NOMINATIM_DATA_PATH:="/srv/nominatim/data"}
NOMINATIM_DATA_LABEL=${NOMINATIM_DATA_LABEL:="data"}
NOMINATIM_PBF_URL=${NOMINATIM_PBF_URL:="http://download.geofabrik.de/asia/maldives-latest.osm.pbf"}
NOMINATIM_POSTGRESQL_DATA_PATH=${NOMINATIM_POSTGRESQL_DATA_PATH:="/var/lib/postgresql/9.3/main"}
# Google Storage variables
NOMINATIM_SA_KEY_PATH=${NOMINATIM_SA_KEY_PATH:=""}
NOMINATIM_PROJECT_ID=${NOMINATIM_PROJECT_ID:=""}
NOMINATIM_GS_BUCKET=${NOMINATIM_GS_BUCKET:=""}


if [ "$NOMINATIM_MODE" == "CREATE" ]; then
    
    # Retrieve the PBF file
    curl $NOMINATIM_PBF_URL --create-dirs -o $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf
    # Allow user accounts read access to the data
    chmod 755 $NOMINATIM_DATA_PATH

    # Start PostgreSQL
    service postgresql start

    # Import data
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim"
    useradd -m -p password1234 nominatim
    sudo -u nominatim /srv/nominatim/build/utils/setup.php --osm-file $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf --all --threads 2

    if [ ! -z "$NOMINATIM_SA_KEY_PATH" ] && [ ! -z "$NOMINATIM_PROJECT_ID" ] && [ ! -z "$NOMINATIM_GS_BUCKET" ]; then
    
        # Stop PostgreSQL
        service postgresql stop

        # Archive PostgreSQL data
        tar cz $NOMINATIM_POSTGRESQL_DATA_PATH | split -b 1024MiB - $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.tgz_

        # Activate the service account to access storage
        gcloud auth activate-service-account --key-file $NOMINATIM_SA_KEY_PATH
        # Set the Google Cloud project ID
        gcloud config set project $NOMINATIM_PROJECT_ID

        # Copy the archive to storage
        gsutil -m cp $NOMINATIM_DATA_PATH/*.tgz* $NOMINATIM_GS_BUCKET/$NOMINATIM_DATA_LABEL
        
        # Start PostgreSQL
        service postgresql start
        
    fi
    
else

    if [ ! -z "$NOMINATIM_SA_KEY_PATH" ] && [ ! -z "$NOMINATIM_PROJECT_ID" ] && [ ! -z "$NOMINATIM_GS_BUCKET" ]; then
    
        # Activate the service account to access storage
        gcloud auth activate-service-account --key-file $NOMINATIM_SA_KEY_PATH
        # Set the Google Cloud project ID
        gcloud config set project $NOMINATIM_PROJECT_ID

        # Copy the archive from storage
        mkdir -p $NOMINATIM_DATA_PATH
        gsutil -m cp $NOMINATIM_GS_BUCKET/$NOMINATIM_DATA_LABEL/*.tgz* $NOMINATIM_DATA_PATH

        # Remove any files present in the target directory
        rm -rf $NOMINATIM_POSTGRESQL_DATA_PATH/*
        
        # Extract the archive
        cat $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.tgz_* | tar xz -C $NOMINATIM_POSTGRESQL_DATA_PATH --strip-components=5
        
        # Start PostgreSQL
        service postgresql start
        
    fi
    
fi

# Tail Apache logs
tail -f /var/log/apache2/* &

# Run Apache in the foreground
/usr/sbin/apache2ctl -D FOREGROUND
