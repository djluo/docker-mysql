#!/bin/bash

#echo -n "mysql init: "

PW="Z2AZ3yUMGG8bVG2CWgEi"
HOST=`hostname`
SOCK="/mysql/logs/mysql.sock"
User="${User:=mysql}"

/usr/bin/mysql_install_db --datadir=/mysql/data >/dev/null
chown ${User}.${User} /mysql/{data,log,logs}

/usr/bin/mysqld_safe --socket=${SOCK} >/dev/null &

__wait_sock() {
  local i=1
  while [ $i -lt 120 ]
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
grant all privileges on *.* to root@"${HOST}"   identified by "${PW}";
grant all privileges on *.* to root@"localhost" identified by "${PW}";
grant all privileges on *.* to root@"127.0.0.1" identified by "${PW}";
grant all privileges on *.* to root@"%"         identified by "${PW}";

grant shutdown on *.* to shutdown@'localhost';
grant shutdown on *.* to shutdown@'127.0.0.1';

drop user root@'::1';
delete from mysql.user where user='';

drop database test;

flush privileges;
EOF

/usr/bin/mysqladmin -S ${SOCK} shutdown -uroot -p${PW} >/dev/null
#__wait_sock

touch /mysql/data/.init_lock

echo "======================================================"
echo "The initial password for the mysql(root): ${PW}"
echo "======================================================"
