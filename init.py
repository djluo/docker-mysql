#!/usr/bin/env python
# vim:set et ts=2 sw=2 fileencoding=utf-8:

import os
import re
import pwd
import random

# 添加用户, 不添加可能也没问题
uid = os.getenv('User_Id', "1000")

if re.match(r'^\d+$', uid) is None:
  print "uid error"
  os._exit(127)

uid = int(uid)

try:
  pwd.getpwuid(uid)
except KeyError:
  os.system('/usr/sbin/useradd -U -u %d -m -s /bin/false docker' % uid)

# 初始化数据库配置文件
working_dir = os.getcwd()
extra_file  = working_dir + "/extra-my.cnf"
super_conf  = "/etc/supervisor/supervisord.conf"
slave_conf  = "/etc/mysql/slave-extra-my.cnf"

# 获取宿主上zabbix用户的组id
def get_zabbix_gid(passwd_file, user="zabbix"):
  group_id = 1000;
  if os.path.isfile(passwd_file):
    pw = open(passwd_file, "r")
    for line in pw:
      fields = line.split(':')
      if str(fields[0]) == str(user):
        group_id = int(fields[3])
        break
    pw.close()
  return group_id

# 用于zabbix监控主从状态
def write_zabbix_my_cnf(name, zabbix_pass, mysqld_sock, zabbix_user="zabbix"):
  my_dir = "/var/lib/zabbix/"
  my_cnf = my_dir + "." + name + ".cnf"
  group_id= get_zabbix_gid("/host-passwd")

  if os.path.isdir(my_dir):
    open_my_cnf = open(my_cnf, "w")
    open_my_cnf.write("[client]\n")
    open_my_cnf.write("user     = %s\n" % zabbix_user)
    open_my_cnf.write("password = %s\n" % zabbix_pass)
    open_my_cnf.write("socket   = %s\n" % mysqld_sock)
    open_my_cnf.close()
    os.chmod(my_cnf, 0640  )
    os.chown(my_cnf, -1, group_id)

# 调整配置文件的路径
if not os.path.isfile("/etc/mysql/modify_complete"):
  os.system("sed -i 's@/MYSQL@%s@' /etc/mysql/my.cnf"     % working_dir)
  os.system("sed -i 's@/MYSQL@%s@' /etc/mysql/debian.cnf" % working_dir)
  os.system("sed -i 's@/path/to/dir@%s@' %s" % ( working_dir, super_conf ) )
  os.system("touch /etc/mysql/modify_complete")

# 默认内存池为128M
pool_size = os.getenv("innodb_buffer_pool_size")
if pool_size:
  os.system("sed -i '/innodb/s@128M@%s@' %s" % ( pool_size, super_conf ) )

# 从库模式
if os.getenv("IS_SLAVE"):
  # 写入zabbix用的文件
  mysqld_name = os.getenv("mysqld_name")
  zabbix_pass = os.getenv("zabbix_pass")
  mysqld_sock = os.getenv("mysqld_sock")
  write_zabbix_my_cnf(mysqld_name,zabbix_pass,mysqld_sock)

  # 从库与主库差异配置文件, 主从库能能直连模式
  if not os.path.isfile(extra_file):
    os.system("cp -fv %s %s" % ( slave_conf, extra_file) )
  # ssh隧道模式
  if os.getenv("IS_TUNNEL") and os.getenv("WITH_SSH"):
    # 生产互信对密钥对
    key_path = working_dir + "/.ssh"
    if not os.path.isdir(key_path):
      os.mkdir(key_path, 0755)
      os.system('ssh-keygen -b 2048 -t rsa -f %s/id_rsa -q -N "" -C Container' % key_path )
      os.system('chown -R docker.docker %s' % key_path)

    # supervisor 子配置文件
    ssh_ip    = os.getenv('ssh_ip')
    ssh_port  = os.getenv('ssh_port',   '932'      )
    ssh_user  = os.getenv('ssh_user',   'tunnel'   )
    mysql_ip  = os.getenv('mysql_ip',   '127.0.0.1')
    mysql_port= os.getenv('mysql_port', '3306'     )

    ssh_cmd  = "/usr/bin/ssh -i %s/id_rsa -p%s -oStrictHostKeyChecking=no -N " % ( key_path, ssh_port )
    ssh_cmd += "-L127.0.0.1:3306:%s:%s %s@%s" % ( mysql_ip, mysql_port, ssh_user, ssh_ip )

    tunnel = open("/etc/supervisor/conf.d/tunnel.conf", "w")
    tunnel.write("[program:tunnel]\n")
    tunnel.write("autorestart=true\n")
    tunnel.write("command=%s\n" % ssh_cmd )
    tunnel.close()

# 其他参数保存到扩展配置中
## 默认binlog 过期时间为3天
expire_logs_days = os.getenv("expire_logs_days")
if expire_logs_days:
  if os.path.isfile(extra_file):
    flag = 0
    extra = open(extra_file, "a+")
    for line in extra.readlines():
      if re.match(r'^expire_logs_days=\d+$', line):
        flag = 1

    if flag == 0:
      extra.write('expire_logs_days=%s\n' % expire_logs_days )

    extra.close()
    if flag == 1:
      os.system("sed -i '/expire_logs_days/s@=.*@=%s@' %s" % ( expire_logs_days, extra_file ) )
    del flag
  else:
    extra = open(extra_file, "w")
    extra.write('[mysqld]\n')
    extra.write('expire_logs_days=%s\n' % expire_logs_days )
    extra.close()

# 启用扩展配置文件
if os.path.isfile(extra_file):
  extra_file="--defaults-extra-file=" + extra_file
  os.system("sed -i 's@mysqld --innodb@mysqld %s --innodb@' %s" % ( extra_file, super_conf ) )

# 确保目录存在
mysql_dirs = [ "./logs", "./log", "./data", "./backup" ]
for dirs in mysql_dirs:
  if not os.path.isdir(dirs):
    os.mkdir(dirs)

# 初始化库
if not os.path.isfile("./data/init_complete"):
  os.system("/init.sh")

# 目录权限
for dirs in mysql_dirs:
  if not dirs == "./backup":
    os.system('chown -R docker.docker %s' % dirs)
  if dirs == "./logs":
    os.chmod(dirs, 0755)
  else:
    os.chmod(dirs, 0700)

# crontab相关操作
minute = random.randint(0, 50)
hour   = random.randint(1,  6)

# 备份和删除历史备份
del_cmd='(cd %s; /xtrab.sh delete >> ./backup/stdout.log 2>&1)' % working_dir
bak_cmd='(cd %s; /xtrab.sh backup >> ./backup/stdout.log 2>&1)' % working_dir

cron = open("./crontab", "w")
cron.write("# Run in the container\n")
cron.write("%02d %d * * * %s\n" % (minute,     hour, del_cmd) )
cron.write("%02d %d * * * %s\n" % (minute + 5, hour, bak_cmd) )
cron.close()

# 同步备份至远程服务器
rsync_pass  = os.getenv('RSYNC_PASSWORD')
rsync_port  = os.getenv('RSYNC_PORT', 2873)
backup_ip   = os.getenv('backup_ip')
backup_dest = os.getenv('backup_dest', 'docker')
#backup_dest += "_" + os.uname()[1]

rsync_cmd = '(/usr/bin/rsync -al --port=%s' % rsync_port

if rsync_pass:
  passwd = open("/rsync.pass", "w")
  passwd.write("%s" % rsync_pass)
  passwd.close()
  os.chmod("/rsync.pass", 0600)
  rsync_cmd += " --password-file=/rsync.pass"

if backup_ip:
  rsync_cmd += " %s/backup/ docker@%s::backup/%s/)" % ( working_dir, backup_ip, backup_dest )
  cron = open("./crontab", "a")
  cron.write("%02d %d * * * %s\n" % (minute, hour + 1, rsync_cmd) )
  cron.close()

os.system("crontab -u root ./crontab")

# 开启crond 进程
if os.path.isfile("/run/crond.pid"):
  os.unlink("/run/crond.pid")
os.system("/usr/sbin/cron")

# 切换运行账号
os.setgid(uid)
os.setuid(uid)

os.execl("/usr/bin/supervisord", "supervisord", "-n")
