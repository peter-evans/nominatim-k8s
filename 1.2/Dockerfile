FROM peterevans/trusty-gcloud:1.1

MAINTAINER Peter Evans <pete.evans@gmail.com>

ENV NOMINATIM_VERSION 2.5.1

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND noninteractive

# Set locale
ENV LANG C.UTF-8
RUN locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8

# Install packages
RUN apt-get -y update \
 && apt-get install -y -qq --no-install-recommends \
    build-essential \
    libxml2-dev \
    libpq-dev \
    libbz2-dev \
    libtool \
    automake \
    libproj-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-thread-dev \
    libexpat-dev \
    gcc \
    proj-bin \
    libgeos-c1 \
    libgeos++-dev \
    php5 \
    php-pear \
    php5-pgsql \
    php5-json \
    php-db \
    libapache2-mod-php5 \
    postgresql \
    postgis \
    postgresql-contrib \
    postgresql-9.3-postgis-2.1 \
    postgresql-server-dev-9.3 \
    curl \
    git \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/* /var/tmp/*

# Build Nominatim
RUN mkdir /nominatim \
 && cd /nominatim \
 && git clone --branch v$NOMINATIM_VERSION --depth 1 --recursive git://github.com/twain47/Nominatim.git ./src \
 && cd src \
 && ./autogen.sh \
 && ./configure \
 && make

# Create Nominatim website
COPY local.php /nominatim/src/settings/local.php
RUN rm -rf /var/www/html/* \
 && /nominatim/src/utils/setup.php --create-website /var/www/html

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
