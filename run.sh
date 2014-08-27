#!/bin/sh

if [ ! -f "/mysql/data/.init_lock" ];then
  /mysql/init.sh
fi

/usr/bin/mysqld_safe >/dev/null
