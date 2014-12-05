#!/bin/bash
# vim:set et ts=2 sw=2:

# chkconfig: 3 90 19
# description:
# processname: mysql container

# 当前工作目录相关
current_dir=`readlink -f $0`
current_dir=`dirname $current_dir`

cd ${current_dir} && export current_dir

images="mysql:2"

action="$1"    # start or stop ...
app_name="$2"  # is container name
shift
shift
port="$@"

app_name=${app_name:=mysql-db}
port="${port:=-p 127.0.0.1:3306:3306}"


# 读取当前应用配置
[ -f  ${current_dir}/.lock_source ] && source ${current_dir}/.lock_source

# 检查输入
if ! `echo ${app_name} | egrep "^[a-z][a-z0-9_-]{0,20}$" >/dev/null` ;then
  echo "app_name bad: $app_name"
  exit 127
fi
if ! `echo ${port} | egrep "^-p[ p0-9:.-]{0,100}$" >/dev/null` ;then
  echo "port bad: $port"
  exit 128
fi


# 检查镜像是否存在
#_check_images() {
#
#}

_usage() {
  echo "Usage: $0 [start|stop|restart|rebuild|remove|debug] [name] [port]..."
  echo "     : name current is \"${app_name}\""
  echo "     : port current is \"${port}\""
  echo "     : name defalut is \"mysql-db\""
  echo "     : port defalut is \"-p 127.0.0.1:3306:3306\""
  exit 127
}

# 等待mysql真的启停完成
_wait() {
  local action="$1"
  local SOCK_FILE="$2"

  try=0
  while [ $try -lt 300 ]
  do
    case "$action" in
      start)
        [ -S ${SOCK_FILE}   ] && try='' && break
      ;;
      stop)
        [ ! -S ${SOCK_FILE} ] && try='' && break
      ;;
    esac

    #echo -n .
    let try+=1
    sleep 1
  done
}

_check_container() {
  local app="$1"
  local status=""
  status=$(sudo docker inspect --format='{{ .State.Running }}' $app 2>/dev/null)
  local retvar=$?

  if [ $retvar -eq 0 ] ;then
    [ "x$status" == "xtrue"  ] && return 0 # exists and running
    [ "x$status" == "xfalse" ] && return 1 # exists and stoped
    return 2 # is images or Unknown
  else
    return 3 # No such image or container
  fi
}
_status() {
  local app_name="$1"
  _check_container ${app_name}
  local cstatus=$?

  echo -en "Status container: ${app_name} \t"

  if [ $cstatus -eq 0 ] ;then
    echo "exists and running"
    echo "        and port: ${port}"
  elif [ $cstatus -eq 1 ];then
    echo "exists and stoped"
    echo "        and port: ${port}"
  elif [ $cstatus -eq 3 ];then
    echo "not exists"
  else
    echo "Unknown\t"
  fi
}
_run() {
  # usage:
  #   call: _run
  #   call: _run debug
  local mode="-d"
  local my_cnf=""

  if [ "x$1" == "xdebug" ];then
    shift
    mode="-ti --rm"
    app_name="debug_$app_name"
    cmd="/bin/bash -l"
    unset port
  else
    cmd="/mysql/run.sh"
  fi

  [ -f ${current_dir}/my.cnf ] && \
    my_cnf="-v ${current_dir}/my.cnf:/mysql/etc/my.cnf:ro"

  sudo docker run $mode $port \
    -e "TZ=Asia/Shanghai"     \
    $my_cnf \
    -v ${current_dir}/log/:/mysql/log/   \
    -v ${current_dir}/logs/:/mysql/logs/ \
    -v ${current_dir}/data/:/mysql/data/ \
    --name ${app_name} ${images} \
    $cmd
}
_start() {
  local app="$1"
  local retvar=1

  echo -en "Start  container: ${app} \t"

  _check_container ${app_name}
  local cstatus=$?

  if [ $cstatus -eq 0 ] ;then
      echo -en "is running\t"
      retvar=0
  elif [ $cstatus -eq 1 ];then
    sudo docker start $app >/dev/null
    retvar=$?
  elif [ $cstatus -eq 3 ];then
    _run >/dev/null
    retvar=$?
  else
    echo -en "Unknown\t"
    retvar=1
  fi

  _wait "start" ${current_dir}/logs/mysql.sock

  if [ $retvar -eq 0 ] && [ -S ${current_dir}/logs/mysql.sock ];then
    # 写入当前应用配置
    if [ ! -f  ${current_dir}/.lock_source ];then
      echo "app_name='${app}'" > ${current_dir}/.lock_source
      echo "port='${port}'"    >>${current_dir}/.lock_source
    fi
    echo "OK"
  else
    echo "Failed"
  fi
}
_stop() {
  local app_name="$1"
  local retvar=1

  echo -en "Stop   container: ${app_name} \t"

  _check_container ${app_name}
  local cstatus=$?

  if [ $cstatus -eq 0 ] ;then
    sudo docker exec ${app_name} \
      mysqladmin -S /mysql/logs/mysql.sock -ushutdown shutdown

    retvar=$?
    _wait "stop" ${current_dir}/logs/mysql.sock
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
    echo "Failed"
  fi
}
_remove(){
  local app_name="$1"
  local retvar=1

  echo -en "Remove container: ${app_name} \t"

  _check_container ${app_name}
  local cstatus=$?

  if [ $cstatus -eq 1 ];then
    sudo docker rm ${app_name} >/dev/null
    retvar=$?
  else
    retvar=1
  fi

  if [ $retvar -eq 0 ];then
    # rm -f ${current_dir}/.lock_source
    echo "OK"
  else
    echo "Failed"
  fi

}
###############

case "$action" in
  start)
    _start $app_name
    ;;
  stop)
    _stop $app_name
    ;;
  debug)
    _run debug
    ;;
  restart)
    _stop  $app_name
    _start $app_name
    ;;
  rebuild)
    _stop   $app_name
    _remove $app_name
    _start  $app_name
    ;;
  remove)
    _stop   $app_name
    _remove $app_name
    ;;
  status)
    _status $app_name
    ;;
  *)
    _usage
    ;;
esac
