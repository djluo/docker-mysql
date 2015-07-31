#!/bin/bash

umask 077

export TZ=Asia/Shanghai
bak_dir=$(date +"%Y")
bak_day=$(date +"%Y%m%d")

temp_dir() {
  [ -d "/mysql/backup" ] || mkdir /mysql/backup
  chmod 700 /mysql/backup

  [ -d "/mysql/backup/temp" ] && rm -rf /mysql/backup/temp
  mkdir /mysql/backup/temp
}

backup() {
  temp_dir
  [ -d "/mysql/backup/$bak_dir" ] || mkdir "/mysql/backup/$bak_dir"
  source /mysql/data/.xtrab

  /usr/bin/innobackupex \
    --slave-info \
    --user=xtrab \
    --password=$xtrab_pw \
    --defaults-file=/mysql/my.cnf   \
    --socket=/mysql/logs/mysql.sock \
    --stream=tar /mysql/backup/temp | gzip > /mysql/backup/${bak_dir}/${bak_day}.tar.gz
}

restore() {
  temp_dir
  local backup_file="/mysql/backup/${bak_dir}/${bak_day}.tar.gz"
  [ "x$1" != "x" ] && backup_file="$1"

  tar xfi $backup_file -C  /mysql/backup/temp/
  innobackupex --apply-log /mysql/backup/temp/

  [ -d "/mysql/backup/restore-bak" ] && rm -rf /mysql/backup/restore-bak
  [ -d "/mysql/backup/restore"     ] && mv /mysql/backup/restore{,-bak}
  mkdir -p /mysql/backup/restore/{data,log}

  sed 's@/mysql/@/mysql/backup/restore/@' /mysql/my.cnf \
    > /mysql/backup/restore/restore-my.cnf

  innobackupex --defaults-file="/mysql/backup/restore/restore-my.cnf" \
               --copy-back /mysql/backup/temp/
  rm -rf /mysql/backup/temp/
}

delete(){
  local mtime="$2"

  [ -d "/mysql/backup/${bak_dir}" ] || return 1

 find "/mysql/backup/${bak_dir}" \
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
