FROM peterevans/trusty-gcloud:1.2.7 as builder

MAINTAINER Peter Evans <pete.evans@gmail.com>

ENV NOMINATIM_VERSION 3.0.1

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND noninteractive

# Install packages
RUN apt-get -y update \
 && apt-get install -y -qq --no-install-recommends \
    build-essential \
    cmake \
    g++ \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libexpat1-dev \
    zlib1g-dev \
    libxml2-dev \
    libbz2-dev \
    libpq-dev \
    libgeos-dev \
    libgeos++-dev \
    libproj-dev \
    postgresql-server-dev-9.3 \
    curl

# Build Nominatim
RUN cd /srv \
 && curl --silent -L http://www.nominatim.org/release/Nominatim-$NOMINATIM_VERSION.tar.bz2 -o v$NOMINATIM_VERSION.tar.bz2 \
 && tar xf v$NOMINATIM_VERSION.tar.bz2 \
 && rm v$NOMINATIM_VERSION.tar.bz2 \
 && mv Nominatim-$NOMINATIM_VERSION nominatim \
 && cd nominatim \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make


FROM peterevans/trusty-gcloud:1.2.7

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND noninteractive

# Set locale and install packages
ENV LANG C.UTF-8
RUN locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8 \
 && apt-get -y update \
 && apt-get install -y -qq --no-install-recommends \
    postgresql-contrib \
    postgresql-9.3-postgis-2.1 \
    postgresql-server-dev-9.3 \
    apache2 \
    php5 \
    php5-pgsql \
    php5-intl \
    libapache2-mod-php5 \
    php-pear \
    php-db \
    curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/* /var/tmp/*

# Copy the application from the builder image
COPY --from=builder /srv/nominatim /srv/nominatim

# Configure Nominatim
COPY local.php /srv/nominatim/build/settings/local.php

# Configure Apache
COPY nominatim.conf /etc/apache2/sites-enabled/000-default.conf

# Allow remote connections to PostgreSQL
RUN echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/9.3/main/pg_hba.conf \
 && echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf

# Set the entrypoint
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
EXPOSE 8080
