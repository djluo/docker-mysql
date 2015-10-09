#!/bin/bash
# vim:set et ts=2 sw=2:

# Author : djluo
# version: 4.0(20150107)

# chkconfig: 3 90 19
# description:
# processname: yys-sh global admin container

[ -r "/etc/baoyu/functions"  ] && source "/etc/baoyu/functions" && _current_dir
[ -f "${current_dir}/docker" ] && source "${current_dir}/docker"

# ex: ...../dir1/dir2/run.sh
# container_name is "dir1-dir2"
_container_name ${current_dir}

images="${registry}/baoyu/mysql55"
#default_port="172.17.42.1:3306:3306"

action="$1"    # start or stop ...
if [ "x$action" == "xexec" ];then
  shift
  exec_cmd=$@
elif [ "x$action" == "xrollback" ];then
  rollback_target="${2:-latest}"
else
  _get_uid "$2"  # uid=xxxx ,default is "1000"
  shift $flag_shift
  unset  flag_shift

  # 转换需映射的端口号
  app_port="$@"  # hostPort
  app_port=${app_port:=${default_port}}
  _port
fi

_backup() {
  local exec_cmd="/xtrab.sh backup"
  _exec
}

_rollback() {
  local bak_suffix=$(date +"%s")
  local exec_cmd="/xtrab.sh restore $rollback_target"
  echo $exec_cmd
  _start
  _exec

  _stop_and_remove

  sudo mv -v ./log  ./log-old$bak_suffix
  sudo mv -v ./data ./data-old$bak_suffix

  sudo mv -v ./backup/restore/{data,log} .
  sudo touch ./data/init_complete
  sudo cp -a ./data-old$bak_suffix/.xtrab ./data/
  _start
}

_run() {
  local mode="-d --restart=always"
  local name="$container_name"
  local cmd=""

  [ -d "${current_dir}/backup" ] || sudo mkdir -m 700 ${current_dir}/backup

  local extra="${current_dir}/extra-my.cnf"
  [ -f ${extra} ] \
    && local volume="-v ${extra}:${extra}:ro"

  [ "x$1" == "xdebug" ] && _run_debug

  sudo docker run $mode $port \
    -e "TZ=Asia/Shanghai"     \
    -e "User_Id=${User_Id}"   \
    $volume      \
    -w "${current_dir}" \
    -e "backup_dest=$name"     \
    -e "RSYNC_PASSWORD=docker" \
    -e "backup_ip=172.17.42.1" \
    -v ${current_dir}/log/:${current_dir}/log/   \
    -v ${current_dir}/logs/:${current_dir}/logs/ \
    -v ${current_dir}/data/:${current_dir}/data/ \
    -v ${current_dir}/backup/:${current_dir}/backup/ \
    --name ${name} ${images} \
    $cmd
}
###############
_call_action $action
