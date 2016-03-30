#!/usr/bin/env python
# encoding: UTF-8

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
super_conf  = "/etc/supervisor/supervisord.conf"

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
if os.path.isfile("/run/crond.pid"):
  os.unlink("/run/crond.pid")

minute = random.randint(0, 50)
hour   = random.randint(1,  6)

# 备份和删除历史备份
del_cmd='(cd %s; /xtrab.sh delete >> ./backup/stdout.log 2>&1)' % working_dir
bak_cmd='(cd %s; /xtrab.sh backup >> ./backup/stdout.log 2>&1)' % working_dir

cron = open("./crontab", "w")
cron.write("%02d %d * * * %s\n" % (minute,     hour, del_cmd) )
cron.write("%02d %d * * * %s\n" % (minute + 5, hour, bak_cmd) )
cron.close()

# 同步备份至远程服务器
rsync_pass  = os.getenv('RSYNC_PASSWORD')
rsync_port  = os.getenv('RSYNC_PORT', 2873)
backup_ip   = os.getenv('backup_ip')
backup_dest = os.getenv('backup_dest', 'docker')
backup_dest += "_" + os.uname()[1]

rsync_cmd = '(/usr/bin/rsync -al --port=%s' % rsync_port

if rsync_pass:
  passwd = open("/rsync.pass", "w", 0600)
  passwd.write("%s" % rsync_pass)
  passwd.close()
  rsync_cmd += " --password-file=/rsync.pass"

if backup_ip:
  rsync_cmd += " %s/backup/ docker@%s::backup/%s/)" % ( working_dir, backup_ip, backup_dest )
  cron = open("./crontab", "a")
  cron.write("%02d %d * * * %s\n" % (minute, hour + 1, rsync_cmd) )
  cron.close()

os.system("crontab -u root ./crontab")

# 切换运行账号
os.setgid(uid)
os.setuid(uid)

os.execl("/usr/bin/supervisord", "supervisord", "-n")
