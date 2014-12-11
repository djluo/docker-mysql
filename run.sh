#!/bin/bash
# vim:set et ts=2 sw=2:

# Author : djluo
# version: 2.0(20141210)

# chkconfig: 3 90 19
# description:
# processname: mysql container

# 当前工作目录相关
current_dir=`dirname $0`
current_dir=`readlink -f $current_dir`
cd ${current_dir} && export current_dir

images="by-mysql:5.5.40v3"
default_name="mysql-db"
default_port="3306"

action="$1"    # start or stop ...
app_name="$2"  # container name
app_port="$3"  # hostPort

app_name=${app_name:=${default_name}}
app_port=${app_port:=${default_port}}

# 以端口号做用户ID
User_Id=${app_port/*:/}

port="-p 127.0.0.1:$app_port:${default_port}"

# 简单的判断端口参数是否带IP地址
if [ ${#app_port} -gt 6 ];then
  port="-p $app_port:${default_port}"
fi

[ -r "/etc/baoyu/functions"   ] && source "/etc/baoyu/functions"
[ -f "${current_dir}/.config" ] && source "${current_dir}/.config"

_check_input

_run() {
  local mode="-d"
  local name="$app_name"
  local cmd="/mysql/cmd.sh"

  [ "x$1" == "xdebug" ] && _run_debug

  [ -f ${current_dir}/my.cnf ] && \
    local volume="-v ${current_dir}/my.cnf:/mysql/etc/my.cnf:ro"

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
_start() {
  local retvar=1

  echo -en "Start  container: ${app_name} \t"

  _start_or_run

  _wait_mysql_sock "start" ${current_dir}/logs/mysql.sock
  _wait_container_start

  if [ $retvar -eq 0 ] && [ -S ${current_dir}/logs/mysql.sock ];then
    # 写入当前应用配置
    _save_argv ${current_dir}/.config
    echo "OK"
  else
    echo "Failed"
  fi
}
_stop() {
  local retvar=9

  echo -en "Stop   container: ${app_name} \t"

  _check_container
  local cstatus=$?

  if [ $cstatus -eq 0 ] ;then

    sudo docker exec ${app_name} \
      mysqladmin -S /mysql/logs/mysql.sock -ushutdown shutdown 2>/dev/null

    _wait_mysql_sock "stop" ${current_dir}/logs/mysql.sock
    _wait_container_stop

    _check_container
    local retvar2=$?
    [ $retvar2 -eq 1 ] && retvar=0

  elif [ $cstatus -eq 1 ];then
    echo -en "is stoped\t"
    retvar=0
  else
    echo -en "No such container\t"
    retvar=1
  fi

  if [ $retvar -eq 0 ] && [ ! -S ${current_dir}/logs/mysql.sock ];then
    echo "OK"
  else
    echo "${retvar}Failed"
    exit 127
  fi
}

###############
case "$action" in
  start)
    _start
    ;;
  stop)
    _stop
    ;;
  debug)
    _run debug
    ;;
  restart)
    _stop
    _start
    ;;
  rebuild)
    _stop_and_remove
    _start
    ;;
  remove)
    _stop_and_remove
    ;;
  status)
    _status
    ;;
  exec)
    _exec
    ;;
  *)
    _usage
    ;;
esac
