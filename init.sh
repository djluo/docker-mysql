#!/bin/bash

pw=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8`

/usr/bin/mysql_install_db --datadir=/mysql/data --user=mysql

/usr/bin/mysqld_safe &

/usr/bin/mysql -uroot -S /tmp/mysql.sock <<EOF
grant all privileges on *.* to root@'localhost' identified by "yyy";
grant all privileges on *.* to root@'127.0.0.1' identified by "yyy";

drop user root@'';
drop user root@'::1';
delete from mysql.user where user='';
delete from mysql.user where user='root' and host='FJXM-DM-ResPool-VM187';

drop database test;

flush privileges;
EOF
