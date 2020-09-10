#!/bin/bash

if [ "$NOMINATIM_MODE" != "CREATE" ] && [ "$NOMINATIM_MODE" != "RESTORE" ]; then
    # Default to CREATE
    NOMINATIM_MODE="CREATE"
fi

# Defaults
NOMINATIM_DATA_PATH=${NOMINATIM_DATA_PATH:="/srv/nominatim/data"}
NOMINATIM_DATA_LABEL=${NOMINATIM_DATA_LABEL:="data"}
NOMINATIM_PBF_URL=${NOMINATIM_PBF_URL:="http://download.geofabrik.de/asia/maldives-latest.osm.pbf"}
NOMINATIM_POSTGRESQL_DATA_PATH=${NOMINATIM_POSTGRESQL_DATA_PATH:="/var/lib/postgresql/9.5/data"}
# Google Storage variables
NOMINATIM_SA_KEY_PATH=${NOMINATIM_SA_KEY_PATH:=""}
NOMINATIM_PROJECT_ID=${NOMINATIM_PROJECT_ID:=""}
NOMINATIM_GS_BUCKET=${NOMINATIM_GS_BUCKET:=""}
NOMINATIM_PG_THREADS=${NOMINATIM_PG_THREADS:=2}

download_pbf() {
    # Retrieve the PBF file
    curl -L $NOMINATIM_PBF_URL --create-dirs -o $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf
    # Allow user accounts read access to the data
    chmod 755 $NOMINATIM_DATA_PATH
}

local_postgres_service_control() {
  # Controls state of the local postges instance
  state=$1
  service postgresql "${state}"
}

postgres_datadir() {
  # run initdb if we don't have good contents
  sed -i "s:data_directory.*:data_directory = '${NOMINATIM_POSTGRESQL_DATA_PATH}':" /etc/postgresql/9.5/main/postgresql.conf
  if [ ! -f ${NOMINATIM_POSTGRESQL_DATA_PATH}/PG_VERSION ]
  then
    sudo -u postgres /usr/lib/postgresql/9.5/bin/initdb -D ${NOMINATIM_POSTGRESQL_DATA_PATH}
  fi
}

postgres_initial_setup() {
    # Add/create users
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
    # drop the existing database if it exists
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim"
    useradd -m -p password1234 nominatim
}

nominatim_setup() {
  # run setup with appropriate settings/files
    sudo -u nominatim /srv/nominatim/build/utils/setup.php --osm-file $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.osm.pbf --all --threads $NOMINATIM_PG_THREADS
}

google_cloud_setup(){
  # activate settings to perform actions on google cloud
  gcloud auth activate-service-account --key-file $NOMINATIM_SA_KEY_PATH
  # Set the Google Cloud project ID
  gcloud config set project $NOMINATIM_PROJECT_ID
}

backup_local_db() {
  # backup local db to upload to make for quick restores
  tar cz $NOMINATIM_POSTGRESQL_DATA_PATH | split -b 1024MiB - $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.tgz_
}

copy_google_bucket_data(){
  source=$1
  destination=$2
  gsutil -m cp "${source}" "${destination}"
}


if [ "$NOMINATIM_MODE" == "CREATE" ]
then
  postgres_datadir
  download_pbf
  local_postgres_service_control start
  postgres_initial_setup
  nominatim_setup
  if [ -n "$NOMINATIM_SA_KEY_PATH" ] && [ -n "$NOMINATIM_PROJECT_ID" ] && [ -n "$NOMINATIM_GS_BUCKET" ]
  then
    local_postgres_service_control stop
    backup_local_db
    google_cloud_setup
    copy_google_bucket_data $NOMINATIM_DATA_PATH/*.tgz* $NOMINATIM_GS_BUCKET/$NOMINATIM_DATA_LABEL
    local_postgres_service_control start
  fi
  # exit after initializing everything so main containers can start
  exit 0
else
  if [ -n "$NOMINATIM_SA_KEY_PATH" ] && [ -n "$NOMINATIM_PROJECT_ID" ] && [ -n "$NOMINATIM_GS_BUCKET" ]
  then
    google_cloud_setup
    mkdir -p ${NOMINATIM_DATA_PATH}
    copy_google_bucket_data $NOMINATIM_GS_BUCKET/$NOMINATIM_DATA_LABEL/*.tgz* $NOMINATIM_DATA_PATH
    # Remove any files present in the target directory
    rm -rf ${NOMINATIM_POSTGRESQL_DATA_PATH:?}/*

    # Extract the archive
    cat $NOMINATIM_DATA_PATH/$NOMINATIM_DATA_LABEL.tgz_* | tar xz -C $NOMINATIM_POSTGRESQL_DATA_PATH --strip-components=5
  fi
fi

# start postgres locally
postgres_datadir
local_postgres_service_control start
# Tail Apache logs
tail -f /var/log/apache2/* &

# Run Apache in the foreground
/usr/sbin/apache2ctl -D FOREGROUND
