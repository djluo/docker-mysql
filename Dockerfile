# Mysql Community
#
# Version 1

FROM centos
MAINTAINER djluo <dj.luo@baoyugame.com>

RUN rpm -ivh http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
RUN yum --disablerepo=mysql56-community \
        --enablerepo=mysql55-community  \
        -y install mysql-community-server mysql-community-client; yum clean all

RUN mkdir -p /mysql/{etc,data,log,logs}
WORKDIR      /mysql
VOLUME       ["/mysql/etc", "/mysql/data", "/mysql/log", "/mysql/logs"]
ADD          ./run.sh  /mysql/run.sh
ADD          ./init.sh /mysql/init.sh

EXPOSE       3306
CMD          [ "/mysql/run.sh" ]
