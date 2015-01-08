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

images="${registry}/baoyu/mysql"
#default_port="172.17.42.1:3306:3306"

action="$1"    # start or stop ...
_get_uid "$2"  # uid=xxxx ,default is "1000"
shift $flag_shift
unset  flag_shift

# 转换需映射的端口号
app_port="$@"  # hostPort
app_port=${app_port:=${default_port}}
_port

_run() {
  local mode="-d"
  local name="$container_name"
  local cmd=""

  [ -f ${current_dir}/extra-my.cnf ] \
    && local volume="-v ${current_dir}/extra-my.cnf:/mysql/extra-my.cnf:ro"

  [ "x$1" == "xdebug" ] && _run_debug

  sudo docker run $mode $port \
    -e "TZ=Asia/Shanghai"     \
    -e "User_Id=${User_Id}"   \
    $volume      \
    -w "/mysql/" \
    -v ${current_dir}/log/:/mysql/log/   \
    -v ${current_dir}/logs/:/mysql/logs/ \
    -v ${current_dir}/data/:/mysql/data/ \
    --name ${name} ${images} \
    $cmd
}
###############
_call_action $action
