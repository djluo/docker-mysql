# Mysql Community
#
# Version 1

FROM debian
MAINTAINER djluo <dj.luo@baoyugame.com>

ADD ./setup/sources.list /etc/apt/
ADD ./setup/ /mysql/

ENV DEBIAN_FRONTEND noninteractive

RUN export http_proxy="http://172.17.42.1:80/" \
    && apt-get update \
    && apt-get install -y locales procps mysql-client mysql-server \
    && apt-get clean    \
    && unset http_proxy \
    && localedef -c -i zh_CN -f UTF-8 zh_CN.UTF-8 \
    && rm -rf usr/share/locale \
    && rm -rf usr/share/man    \
    && rm -rf usr/share/doc    \
    && rm -rf usr/share/info   \
    && find var/lib/apt -type f -exec rm -fv {} \; \
    && rm -rf etc/mysql/my.cnf     \
    && rm -rf etc/mysql/debian.cnf \
    && ln -sv /mysql/my.cnf /etc/mysql/my.cnf     \
    && ln -sv /mysql/my.cnf /etc/mysql/debian.cnf

EXPOSE  3306
WORKDIR /mysql
VOLUME  ["/mysql/data", "/mysql/log", "/mysql/logs"]
CMD     [ "/mysql/cmd.sh" ]
