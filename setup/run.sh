#!/bin/bash

if [ ! -f "/mysql/data/.init_lock" ];then
  /mysql/init.sh
fi

exec /usr/bin/mysqld_safe >/dev/null
