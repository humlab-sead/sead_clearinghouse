FROM php:7.2-cli-buster as clearinghouse-base

ARG container_version=1.0
ARG container_maintainer=roger.mahler@umu.se
ARG container_build_date=2019-06-01

ARG source_branch=master
ENV source_branch=${source_branch}

RUN apt-get update && \
    apt-get install -y \
       apt-transport-https \
       lsb-release ca-certificates \
       libpq-dev && \
	docker-php-ext-install pdo pdo_pgsql

FROM clearinghouse-base as builder-base

RUN apt-get install -y  \
       wget \
       curl \
       gnupg \
       unzip \
       git

RUN curl -sL https://deb.nodesource.com/setup_11.x  | bash - && \
    apt-get -y install nodejs

COPY . /tmp

WORKDIR /tmp

RUN mkdir -p /tmp/deploy && \
    cd /tmp && \
    if [ -d ./src ]; then \
        echo "Building from source in context" && \
        mkdir -p /sead_clearinghouse ; \
        mv * /sead_clearinghouse ; \
        mv /sead_clearinghouse /tmp; \
    else \
        echo "Building from source in Github repository" ; \
        git clone --branch ${source_branch} --single-branch https://github.com/humlab/sead_clearinghouse.git ; \
    fi && \
    cd /tmp/sead_clearinghouse/src && \
    rm -rf ./vendor && \
    wget -q -O ./composer.phar https://getcomposer.org/composer.phar && \
    php ./composer.phar install && \
    php ./composer.phar dump-autoload -o && \
    mkdir -p /tmp/sead_clearinghouse/src/api/api-cache

RUN cd /tmp/sead_clearinghouse && \
    npm install && \
    npx webpack --mode production --config webpack.config.js --no-color

FROM clearinghouse-base

LABEL maintainer="${clearinghouse_maintainer}"
LABEL build_date="${container_build_date}"

WORKDIR /

RUN mkdir -p /home/clearinghouse/

COPY --from=builder-base /tmp/sead_clearinghouse/public /home/clearinghouse/public
COPY --from=builder-base /tmp/sead_clearinghouse/src/api /home/clearinghouse/public/api
COPY --from=builder-base /tmp/sead_clearinghouse/src/vendor /home/clearinghouse/public/vendor


#RUN groupadd -r clearinghouse_group && useradd -r -g clearinghouse_group clearinghouse_user
#RUN chown -R clearinghouse_user:clearinghouse_group /home/clearinghouse

WORKDIR /home/clearinghouse/public

EXPOSE 8060

CMD exec php -S 0.0.0.0:8060 -t .

