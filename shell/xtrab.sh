#!/bin/bash

current_dir=`readlink -f $PWD`
cd ${current_dir} && export current_dir

umask 077

export TZ=Asia/Shanghai
bak_day=$(date +"%Y%m%d-%H%M%S")

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

restore() {
  supervisorctl stop mysqld

  temp_dir
  local backup_file="$1"
  if [ "x$backup_file" == "xlatest" ];then
    backup_file="./backup/latest-backup.tar.gz"
  else
    backup_file="./backup/$backup_file"
    [ -f $backup_file ] || { echo " No backup file"; exit 127; }
  fi

  tar xfi $backup_file -C  ./backup/temp/
  innobackupex --apply-log ./backup/temp/

  # 移动现有data 和log 下的文件至备份目录
  mkdir -v ./backup/data-${bak_day} ./backup/log-${bak_day}
  mv ./data/*      ./backup/data-${bak_day}
  mv ./data/.xtrab ./backup/data-${bak_day}
  mv ./log/*  ./backup/data-${bak_day}

  innobackupex --defaults-file="/etc/mysql/my.cnf" \
               --copy-back ./backup/temp/

  rm -rf ./backup/temp/

  chown docker.docker -R ./data ./log
  cp -av ./backup/data-${bak_day}/.xtrab ./data/
  supervisorctl start mysqld
}

delete(){
  local mtime="$2"

  find "./backup/" \
   -type f -mtime +${mtime:-7} -name "*.tar.gz" \
   -exec rm -fv {} \;
}

case "$1" in
  backup)
    backup
    ;;
  restore)
    restore $2
    ;;
  delete)
    delete $2
    ;;
  *)
    echo "In Docker Container"
    echo "Usage: $0 [backup|restore|delete]"
    echo "     # backup or restore or delete to ./backup/"
    echo "Usage: $0 restore [latest|20150625-123456.tar.gz]"
    echo "     # restore the backup of latest or 20150625-123456 "
    echo "Usage: $0 delete  [7|15|30]"
    echo "     # delete  the backup of [7|15|30] day ago"
    echo
  ;;
esac
