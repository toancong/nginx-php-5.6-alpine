FROM wodby/nginx-alpine:v1.0.4
MAINTAINER Wodby <hello@wodby.com>

RUN export PHP_ACTIONS_VER="master" && \
    export TWIG_VER="1.24.0" && \
    export WALTER_VER="1.3.0" && \
    export GO_AWS_S3_VER="v1.0.0" && \

    echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \

    # Install common packages
    apk add --update \
        git \
        nano \
        grep \
        sed \
        curl \
        wget \
        tar \
        gzip \
        pcre \
        perl \
        openssh \
        patch \
        patchutils \
        diffutils \
        postfix \
        && \

    # Add PHP actions
    cd /tmp && \
    git clone https://github.com/Wodby/php-actions-alpine.git && \
    cd php-actions-alpine && \
    git checkout $PHP_ACTIONS_VER && \
    rsync -av rootfs/ / && \

    # Install PHP specific packages
    apk add --update \
        mariadb-client \
        imap \
        redis \
        imagemagick \
        && \

    # Install PHP extensions
    apk add --update \
        php \
        php-cli \
        php-fpm \
        php-opcache \
        php-xml \
        php-ctype \
        php-ftp \
        php-gd \
        php-json \
        php-posix \
        php-curl \
        php-dom \
        php-pdo \
        php-pdo_mysql \
        php-sockets \
        php-zlib \
        php-mcrypt \
        php-pcntl \
        php-mysqli \
        php-bz2 \
        php-pear \
        php-exif \
        php-phar \
        php-openssl \
        php-posix \
        php-zip \
        php-calendar \
        php-iconv \
        php-imap \
        php-soap \
        php-memcache \
        php-redis@testing \
        php-xdebug@testing \
        && \

    # Configure php.ini
    sed -i "s/^expose_php.*/expose_php = Off/" /etc/php/php.ini && \
    sed -i "s/^;date.timezone.*/date.timezone = UTC/" /etc/php/php.ini && \
    sed -i "s/^memory_limit.*/memory_limit = -1/" /etc/php/php.ini && \
    sed -i "s/^max_execution_time.*/max_execution_time = 300/" /etc/php/php.ini && \
    sed -i "s/^post_max_size.*/post_max_size = 512M/" /etc/php/php.ini && \
    sed -i "s/^upload_max_filesize.*/upload_max_filesize = 512M/" /etc/php/php.ini && \
    echo "extension_dir = \"/usr/lib/php/modules\"" | tee -a /etc/php/php.ini && \
    echo "error_log = \"/var/log/php/error.log\"" | tee -a /etc/php/php.ini && \

    # Configure php log dir
    mkdir /var/log/php && \
    touch /var/log/php/error.log && \
    touch /var/log/php/fpm-error.log && \
    touch /var/log/php/fpm-slow.log && \
    chown -R wodby:wodby /var/log/php && \

    # Install Twig template engine
    apk add --update \
        php-dev \
        pcre-dev \
        build-base \
        autoconf \
        libtool \
        && \

    wget -qO- https://github.com/twigphp/Twig/archive/v${TWIG_VER}.tar.gz | tar xz -C /tmp/ && \
    cd /tmp/Twig-${TWIG_VER}/ext/twig && \
    phpize && ./configure && make && make install && \
    echo 'extension=twig.so' > /etc/php/conf.d/twig.ini && \

    # Install PHP extensions through Pecl
    sed -ie 's/-n//g' /usr/bin/pecl && \
    echo '\n' | pecl install uploadprogress && \
    apk --update add imagemagick-dev && \
    echo '\n' | pecl install imagick && \
    echo 'extension=imagick.so' > /etc/php/conf.d/imagick.ini && \
    echo 'extension=uploadprogress.so' > /etc/php/conf.d/uploadprogress.ini && \

    # Purge dev APK packages
    apk del --purge \
        *-dev \
        build-base \
        autoconf \
        libtool \
        && \

    # Cleanup after phpizing
    cd / && rm -rf /usr/include/php /usr/lib/php/build /usr/lib/php/modules/*.a && \

    # Remove Redis binaries and config
    rm -f \
        /usr/bin/redis-benchmark \
        /usr/bin/redis-check-aof \
        /usr/bin/redis-check-dump \
        /usr/bin/redis-sentinel \
        /usr/bin/redis-server \
        /etc/redis.conf \
        && \

    # Define Git global config
    git config --global user.name "Administrator" && \
    git config --global user.email "admin@wodby.com" && \
    git config --global push.default current && \

    # Install composer, drush and wp-cli
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    git clone https://github.com/drush-ops/drush.git /usr/local/src/drush && \
    cd /usr/local/src/drush && \
    ln -sf /usr/local/src/drush/drush /usr/bin/drush && \
    composer install && rm -rf ./.git && \
    composer create-project wp-cli/wp-cli /usr/local/src/wp-cli --no-dev && \
    ln -sf /usr/local/src/wp-cli/bin/wp /usr/bin/wp && \
    rm -rf /root/.composer/cache && \

    # Install Walter tool
    wget -qO- https://github.com/walter-cd/walter/releases/download/v${WALTER_VER}/walter_${WALTER_VER}_linux_amd64.tar.gz | tar xz -C /tmp/ && \
    mkdir /opt/wodby/bin && \
    cp /tmp/walter_linux_amd64/walter /opt/wodby/bin && \

    # Install go-aws-s3
    wget -qO- https://s3.amazonaws.com/wodby-releases/go-aws-s3/${GO_AWS_S3_VER}/go-aws-s3.tar.gz | tar xz -C /tmp/ && \
    cp /tmp/go-aws-s3 /opt/wodby/bin && \

    # Fix permissions
    chmod 755 /root && \

    # Final cleanup
    rm -rf /var/cache/apk/* /tmp/* /usr/share/man

COPY rootfs /
