#!/bin/bash
set -x

[ "x$password" != "x" ] && pw="-p$password"

if [ "x$IS_TUNNEL" != "x" -a "x$WITH_SSH" != "x" ];then
  MASTER_HOST="127.0.0.1"
  MASTER_PORT="3306"
fi

/usr/bin/mysql -S ${SOCK} -uroot $pw <<EOF
slave stop;

CHANGE MASTER TO
  MASTER_HOST='${MASTER_HOST}',
  MASTER_PORT=${MASTER_PORT},
  MASTER_USER='${MASTER_USER:-slave}',
  MASTER_PASSWORD='${MASTER_PASSWORD}',
  MASTER_LOG_FILE='${MASTER_LOG_FILE:-mysql-bin.000001}',
  MASTER_LOG_POS=${MASTER_LOG_POS:-107};

slave start;
EOF
[ $? -eq 0 ] && touch ./data/slave_complete
