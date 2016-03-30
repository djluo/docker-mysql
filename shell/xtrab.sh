#!/bin/bash

current_dir=`readlink -f $PWD`
cd ${current_dir} && export current_dir

umask 077

export TZ=Asia/Shanghai
bak_day=$(date +"%Y%m%d-%H%M%S")

_usage() {
    echo "In Docker Container"
    echo "Usage: $0 backup"
    echo "     : backup  to ./backup/%Y%m%d-%H%M%S.tar.gz"
    echo
    echo "Usage: $0 restore [latest|20150625-123456.tar.gz]"
    echo "     : restore the backup of latest or 20150625-123456 "
    echo
    echo "Usage: $0 delete  [7|15|30]"
    echo "     : delete  the backup of [7|15|30] day ago"
    echo "Usage: $0 list"
    echo "     : ls -l ./backup/*tar.gz"
    echo
    exit 127;
}

temp_dir() {
  [ -d "./backup/temp" ] && rm -rf ./backup/temp
  mkdir ./backup/temp
}

backup() {
  temp_dir
  source ./data/.xtrab

  /usr/bin/innobackupex \
    --defaults-file=/etc/mysql/my.cnf   \
    --slave-info --user=xtrab --password=$xtrab_pw \
    --stream=tar ./backup/temp | gzip > ./backup/${bak_day}.tar.gz

  pushd ./backup >/dev/null
  local latest="latest-backup.tar.gz"
  [ -L "$latest" ] && rm -f $latest
  echo
  ln -sv ${current_dir}/backup/${bak_day}.tar.gz $latest
  popd >/dev/null

  rm -rf ./backup/temp/
}

_wait_sock() {
  local i=1
  while [ $i -lt 300 ]
  do
    [ -S "./logs/mysql.sock" ] && break
    sleep 1
    let i+=1
  done
}
restore() {

  temp_dir
  local backup_file="$1"
  if [ "x$backup_file" == "xlatest" ];then
    backup_file="./backup/latest-backup.tar.gz"
  else
    backup_file="./backup/$backup_file"
    [ -f $backup_file ] || { echo " No backup file...?";  _usage; }
  fi

  # 停mysql
  supervisorctl stop mysqld

  [ -S "./logs/mysql.sock" ] && sleep 2
  [ -S "./logs/mysql.sock" ] && { echo "stop mysqld error?"; exit 127; }

  # 准备之前备份的数据
  tar xfi $backup_file -C  ./backup/temp/
  innobackupex --apply-log ./backup/temp/

  # 移动正式data 和log 下的文件至备份目录
  mkdir -v ./backup/data-${bak_day} ./backup/log-${bak_day}
  mv ./data/*      ./backup/data-${bak_day}
  mv ./data/.xtrab ./backup/data-${bak_day}
  mv ./log/*       ./backup/log-${bak_day}

  # 将备份数据复制回正式目录
  innobackupex --defaults-file="/etc/mysql/my.cnf" \
               --copy-back ./backup/temp/

  rm -rf ./backup/temp/

  chown docker.docker -R ./data ./log

  # 将标志位重新复制回来
  cp -av ./backup/data-${bak_day}/.xtrab        ./data/
  cp -av ./backup/data-${bak_day}/init_complete ./data/

  supervisorctl start mysqld
  _wait_sock
  [ -S "./logs/mysql.sock" ] || { echo "start mysqld error?"; exit 127; }

}

# 删除备份文件
delete(){
  local mtime="$2"

  find "./backup/" \
   -type f -mtime +${mtime:-7} -name "*.tar.gz" \
   -exec rm -fv {} \;
}

# 列出备份文件
_list() {
  pushd ./backup >/dev/null
  ls -l *tar.gz
}

prog=$(basename $0)
if echo "$prog" | egrep -q "^(backup|restore|list)$" ;then
  action="$prog"
  args="$1"
else
  action="$1"
  args="$2"
fi

case "$action" in
  backup)
    backup
  ;;
  restore)
    restore $args
  ;;
  delete)
    delete $2
  ;;
  list)
    _list
  ;;
  *)
    _usage
  ;;
esac
