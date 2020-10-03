#!/bin/bash -xv

# Script to set up Nominatim database for multiple countries

# Steps to follow:

#     *) Get the pbf files from server

#     *) Set up sequence.state for updates

#     *) Merge the pbf files into a single file.

#     *) Setup nominatim db using 'setup.php --osm-file'

# Hint:
#
# Use "bashdb ./update_database.sh" and bashdb's "next" command for step-by-step
# execution.

# ******************************************************************************

touch2() { mkdir -p "$(dirname "$1")" && touch "$1" ; }

mkdir2() { mkdir -p "$(dirname "$1")" ; }

# ******************************************************************************
# Configuration section: Variables in this section should be set according to your requirements

NOMINATIM_PG_THREADS=${NOMINATIM_PG_THREADS:=2}
NOMINATIM_CACHE=${NOMINATIM_CACHE:=8000}

# REPLACE WITH LIST OF YOUR "COUNTRIES":

COUNTRIES=${COUNTRIES:="europe/monaco europe/andorra"}

# SET TO YOUR NOMINATIM build FOLDER PATH:

NOMINATIMBUILD=${NOMINATIMBUILD:="/srv/nominatim/build"}
SETUPFILE="$NOMINATIMBUILD/utils/setup.php"
UPDATEFILE="$NOMINATIMBUILD/utils/update.php"

# SET TO YOUR update FOLDER PATH:

UPDATEDIR=${NOMINATIM_DATA_PATH:="/srv/nominatim/data"}

# SET TO YOUR replication server URL:

BASEURL="https://download.geofabrik.de"
DOWNCOUNTRYPOSTFIX="-updates.osm.pbf"

# End of configuration section
# ******************************************************************************

COMBINEFILES="osmium merge"

mkdir -p ${UPDATEDIR}
cd ${UPDATEDIR}
rm -rf tmp
mkdir -p tmp
cd tmp

for COUNTRY in $COUNTRIES;
do
    echo "===================================================================="
    echo "$COUNTRY"
    echo "===================================================================="
    DIR="$UPDATEDIR/$COUNTRY"
    FILE="$DIR/configuration.txt"
    DOWNURL="$BASEURL/$COUNTRY-updates/"
    IMPORTFILE=$COUNTRY$DOWNCOUNTRYPOSTFIX
    IMPORTFILEPATH=${UPDATEDIR}/tmp/${IMPORTFILE}

    mkdir2 $IMPORTFILEPATH
    touch2 ${DIR}/sequence.state
    pyosmium-get-changes -f ${DIR}/sequence.state -o $IMPORTFILEPATH -vv --server $DOWNURL --size 1000

    COMBINEFILES="${COMBINEFILES} ${IMPORTFILEPATH}"
    echo $IMPORTFILE
    echo "===================================================================="
done


echo "${COMBINEFILES} -o /tmp/combined.osm.pbf"
${COMBINEFILES} -o /tmp/combined.osm.pbf

echo "===================================================================="
echo "Updating nominatim db"
${UPDATEFILE} --import-file /tmp/combined.osm.pbf --osm2pgsql-cache $NOMINATIM_CACHE 2>&1
${UPDATEFILE} --index --index-instances 3
echo "===================================================================="
