#!/bin/bash
#set -x
#echo -n "mysql init: "

HOST=`hostname`
SOCK="/mysql/logs/mysql-init.sock"

retvar=1

_error() {
  local msg=$@
  echo "$msg"
  exit 127
}

_wait_sock() {
  local i=1
  while [ $i -lt 300 ]
  do
    [ -S "${SOCK}" ] && break
    sleep 1
    let i+=1
  done
}

/usr/bin/mysql_install_db \
  --datadir=/mysql/data >/dev/null || _error "mysql_install_db error?"

chown -R mysql.mysql /mysql/log  \
                     /mysql/logs \
                     /mysql/data

/usr/bin/mysqld_safe --socket=${SOCK} >/dev/null &
[ $? -eq 0 ] || _error "start mysql error?"

_wait_sock

[ -S "${SOCK}" ] || _error "not found sock file?"

/usr/bin/mysql -uroot -S ${SOCK} <<EOF
#grant all privileges on *.* to root@"localhost";
#grant all privileges on *.* to root@"127.0.0.1";
#grant all privileges on *.* to root@"%"       ;

grant shutdown on *.* to shutdown@'localhost';
grant shutdown on *.* to shutdown@'127.0.0.1';

drop user root@'::1';
drop user root@"${HOST}";
delete from mysql.user where user='';

#drop database test;

flush privileges;
EOF
[ $? -eq 0 ] || _error "change privileges error?"

/usr/bin/mysqladmin -S ${SOCK} -ushutdown shutdown >/dev/null
[ -S "${SOCK}" ] && _error "stop mysql error?"

chmod 644 /mysql/logs/error.log /mysql/logs/slowquery.log
chmod 750 /mysql/log /mysql/data

echo "not delele me!!!" > /mysql/data/init_complete

echo "======================================================"
echo "The initial password for the mysql(root): no password,is empty"
echo "======================================================"
