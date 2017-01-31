FROM php:7.1.1-zts

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        supervisor \
        wget \
        git \
        unzip \
        software-properties-common \
        lbzip2

# Setup Composer
WORKDIR /tmp
RUN wget https://getcomposer.org/download/1.3.2/composer.phar && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Build and install pthreads extension (for PHP 7)
RUN docker-php-source extract && \
    git clone https://github.com/krakjoe/pthreads.git /home/pthreads && \
    cd /home/pthreads && \
    phpize && \
    ./configure --with-php-config=/usr/local/bin/php-config && \
    make && \
    make install && \
    docker-php-source delete

# Install needed PHP extensions
RUN docker-php-ext-install pcntl
RUN pecl install ev

# Enable installed extensions
RUN docker-php-ext-enable pcntl
ADD conf/pthreads.ini /usr/local/etc/php/conf.d/pthreads.ini
ADD conf/ev.ini /usr/local/etc/php/conf.d/ev.ini

###
# v8
##
WORKDIR /usr/local/src
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
ENV PATH /usr/local/src/depot_tools:$PATH
# Download v8 source and dependencies
RUN fetch v8 && \
    cd v8 && \
    gclient sync
# Configure and compile
WORKDIR /usr/local/src/v8
RUN python ./tools/dev/v8gen.py x64.release
ADD conf/args.gn /usr/local/src/v8/out.gn/x64.release/args.gn
RUN ninja -C out.gn/x64.release
# Install libv8
RUN mkdir -p /opt/v8/lib && \
    mkdir -p /opt/v8/include && \
    cp out.gn/x64.release/lib*.so /opt/v8/lib/ && \
    cp -R include/* /opt/v8/include && \
    cp out.gn/x64.release/natives_blob.bin /opt/v8/lib && \
    cp out.gn/x64.release/snapshot_blob.bin /opt/v8/lib
###
# end v8
##

# Install v8js extension with compiled libv8
RUN echo '/opt/v8' | pecl install v8js
ADD conf/v8js.ini /usr/local/etc/php/conf.d/v8js.ini

