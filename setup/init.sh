#!/bin/bash

#echo -n "mysql init: "

#PW="Z2AZ3yUMGG8bVG2CWgEi"
PW=""
HOST=`hostname`
SOCK="/mysql/logs/mysql.sock"

/usr/bin/mysql_install_db --datadir=/mysql/data >/dev/null

/usr/bin/mysqld_safe --socket=${SOCK} >/dev/null &

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
__wait_sock

/usr/bin/mysql -uroot -S ${SOCK} <<EOF
#grant all privileges on *.* to root@"${HOST}"   identified by "${PW}";
grant all privileges on *.* to root@"localhost" identified by "${PW}";
grant all privileges on *.* to root@"127.0.0.1" identified by "${PW}";
#grant all privileges on *.* to root@"%"         identified by "${PW}";

grant shutdown on *.* to shutdown@'localhost';
grant shutdown on *.* to shutdown@'127.0.0.1';

drop user root@'::1';
drop user root@"${HOST}";
delete from mysql.user where user='';

drop database test;

flush privileges;
EOF

/usr/bin/mysqladmin -S ${SOCK} -ushutdown shutdown >/dev/null
#__wait_sock

touch /mysql/data/.init_lock

echo "======================================================"
echo "The initial password for the mysql(root): no password,is empty"
echo "======================================================"
