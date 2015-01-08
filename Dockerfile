# Mysql Community
#
# Version 2

FROM       docker.xlands-inc.com/baoyu/debian
MAINTAINER djluo <dj.luo@baoyugame.com>

RUN export http_proxy="http://172.17.42.1:8080/" \
    && export DEBIAN_FRONTEND=noninteractive     \
    && apt-get update \
    && apt-get install -y mysql-client mysql-server \
    && apt-get clean \
    && unset http_proxy DEBIAN_FRONTEND \
    && rm -rf usr/share/locale \
    && rm -rf usr/share/man    \
    && rm -rf usr/share/doc    \
    && rm -rf usr/share/info   \
    && find var/lib/apt -type f -exec rm -fv {} \; \
    && rm -rf etc/mysql/my.cnf     \
    && rm -rf etc/mysql/debian.cnf \
    && ln -sv /mysql/my.cnf     /etc/mysql/my.cnf \
    && ln -sv /mysql/debian.cnf /etc/mysql/debian.cnf \
    && sed -i '146s/\&1/& \& wait/' /usr/bin/mysqld_safe

VOLUME  ["/mysql/data", "/mysql/log", "/mysql/logs"]

ADD ./setup/        /mysql/
ADD ./run.sh        /run.sh
ADD ./functions     /functions
ADD ./entrypoint.pl /entrypoint.pl

ENTRYPOINT ["/entrypoint.pl"]
CMD        ["/usr/bin/mysqld_safe"]
