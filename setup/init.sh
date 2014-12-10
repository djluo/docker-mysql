#!/bin/bash

#echo -n "mysql init: "

#PW="Z2AZ3yUMGG8bVG2CWgEi"
PW=""
HOST=`hostname`
SOCK="/mysql/logs/mysql.sock"

retvar=1

_error() {
  local msg=$@
  echo "$msg"
  exit 127
}

__wait_sock() {
  local i=1
  while [ $i -lt 300 ]
  do
    [ -S "${SOCK}" ] && break
    #echo -n "."
    sleep 1
    let i+=1
  done
  #echo
}

/usr/bin/mysql_install_db --datadir=/mysql/data >/dev/null || _error "mysql_install_db error?"

chown -R docker.docker /mysql/data /mysql/log /mysql/logs  || _error "chown error?"

/usr/bin/mysqld_safe >/dev/null &
[ $? -eq 0 ] || _error "start mysql error?"

__wait_sock

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
