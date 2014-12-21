#!/bin/bash

User_Id="${User_Id:=3306}"
if ! `id -u docker >/dev/null 2>&1` ;then
  /usr/sbin/useradd -U -u ${User_Id} -m -s /bin/false docker
fi

if [ ! -f "/mysql/data/init_complete" ];then
  /mysql/init.sh
fi

exec /usr/bin/mysqld_safe -u docker --user=docker >/dev/null
