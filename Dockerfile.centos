# Mysql Community
#
# Version 1

FROM centos
MAINTAINER djluo <dj.luo@baoyugame.com>

RUN rpm -ivh http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
RUN rpm --import /etc/pki/rpm-gpg/RPM*
RUN yum --disablerepo=mysql56-community    \
        --enablerepo=mysql55-community     \
        -y install mysql-community-server  \
                   mysql-community-client  \
                   hostname; yum clean all

RUN mkdir -p /mysql/{etc,data,log,logs}
WORKDIR      /mysql
ADD          ./run.sh  /mysql/run.sh
ADD          ./init.sh /mysql/init.sh
RUN          chmod +x  /mysql/{run.sh,init.sh}

ADD          ./my.cnf  /mysql/etc/my.cnf
RUN          mv /etc/my.cnf{,.bak} && ln -sv /mysql/etc/my.cnf /etc/

EXPOSE       3306
VOLUME       ["/mysql/etc", "/mysql/data", "/mysql/log", "/mysql/logs"]
CMD          [ "/mysql/run.sh" ]
