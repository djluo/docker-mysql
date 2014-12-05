# Mysql Community
#
# Version 1

FROM debian
MAINTAINER djluo <dj.luo@baoyugame.com>

ADD ./setup/sources.list /etc/apt/
ADD ./setup/ /mysql/

ENV DEBIAN_FRONTEND noninteractive

RUN http_proxy="http://192.168.1.175:80/" apt-get update   \
    && http_proxy="http://192.168.1.175:80/" apt-get install -y mysql-client mysql-server \
    && apt-get clean \
    && rm -rf usr/share/locale \
    && rm -rf usr/share/man    \
    && rm -rf usr/share/doc    \
    && rm -rf usr/share/info   \
    && find var/lib/apt -type f -exec rm -fv {} \; \
    && /usr/sbin/useradd -u 1001 -m docker \
    && rm -rf etc/mysql/my.cnf     \
    && rm -rf etc/mysql/debian.cnf \
    && ln -sv /mysql/my.cnf /etc/mysql/my.cnf     \
    && ln -sv /mysql/my.cnf /etc/mysql/debian.cnf \
    && chmod +x /mysql/run.sh /mysql/init.sh

USER    docker
EXPOSE  3306
WORKDIR /mysql
VOLUME  ["/mysql/data", "/mysql/log", "/mysql/logs"]
CMD     [ "/mysql/run.sh" ]
