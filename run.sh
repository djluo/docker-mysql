#!/bin/sh

if [ ! -f "/mysql/.init_lock" ];then
  /mysql/init.sh
fi

/usr/bin/mysqld_safe >/dev/null
