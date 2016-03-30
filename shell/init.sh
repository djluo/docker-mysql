#!/bin/bash
#set -x
#echo -n "mysql init: "

current_dir=`readlink -f $PWD`
pushd ${current_dir} && export current_dir

HOST=`hostname`
SOCK="${current_dir}/logs/mysql-init.sock"

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
  --datadir=${current_dir}/data >/dev/null || _error "mysql_install_db error?"

chown -R mysql.mysql ./log ./logs ./data

/usr/bin/mysqld_safe --skip-networking --socket=${SOCK} >/dev/null &
[ $? -eq 0 ] || _error "start mysql error?"

_wait_sock

[ -S "${SOCK}" ] || _error "not found sock file?"

xtrab_pw=$(pwgen 16 1)
echo "xtrab_pw=$xtrab_pw" > ./data/.xtrab
chmod 600 ./data/.xtrab

if [ "x$slave_pw" == "x" ] ; then
  slave_pw=$(pwgen 16 1)
  show_slave_pw=$slave_pw
else
  show_slave_pw="see environment variables"
fi

/usr/bin/mysql -uroot -S ${SOCK:-"./logs/mysql.sock -p"} <<EOF
grant all privileges on *.*    to xtrab@"127.0.0.1" identified by "$xtrab_pw";
grant all privileges on *.*    to xtrab@"localhost" identified by "$xtrab_pw";
grant replication slave on *.* to slave@'%'         identified by "$slave_pw";
EOF
[ $? -eq 0 ] || _error "change privileges error?"
unset xtrab_pw

/usr/bin/mysql -uroot -S ${SOCK} <<EOF
grant shutdown on *.* to shutdown@'localhost';
grant shutdown on *.* to shutdown@'127.0.0.1';

drop user root@'::1';
drop user root@"${HOST}";
delete from mysql.user where user='';

drop database if exists test;

flush privileges;
EOF
[ $? -eq 0 ] || _error "change privileges error?"

show_password="no password,is empty"
if [ "x$password" != "x" ] ;then

/usr/bin/mysql -uroot -S ${SOCK} <<EOF
grant all privileges on *.* to root@"localhost" identified by "$password";
grant all privileges on *.* to root@"127.0.0.1" identified by "$password";
grant all privileges on *.* to root@"%"         identified by "$password";
flush privileges;
EOF
  if [ $? -eq 0 ] ;then
    show_password="see environment variables"
  else
    _error "change privileges error?"
  fi
fi

/usr/bin/mysqladmin -S ${SOCK} -ushutdown shutdown >/dev/null
[ -S "${SOCK}" ] && _error "stop mysql error?"

chmod 644 ./logs/error.log
chmod 750 ./log ./data
[ -f ./logs/slowquery.log ] && chmod 644 ./logs/slowquery.log

echo "not delele me!!!" > ./data/init_complete

echo "======================================================"
echo "The initial password for the mysql(root) : $show_password"
echo "The initial password for the mysql(slave): $show_slave_pw"
echo "======================================================"
