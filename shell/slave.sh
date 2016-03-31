#!/bin/bash
set -x

[ "x$password" != "x" ] && pw="-p$password"

/usr/bin/mysql -uroot $pw <<EOF
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