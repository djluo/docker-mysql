#!/usr/bin/python
# vim:set et ts=4 sw=4 fileencoding=utf-8:

import os
import sys
import json
import subprocess

# 获取所有从库的信息like [ ".h3-1.cnf", ".h3-2.cnf" ]
def get_my_cnf(my_dir = "/var/lib/zabbix"):
    all_my_cnf=[]
    for cnf in os.listdir(my_dir):
        cnf_path = os.path.join(my_dir, cnf)
        if os.path.isfile(cnf_path):
           all_my_cnf.append(cnf)
    return all_my_cnf

# 自动发现
def discovery(all_my_cnf):
    data = { "data": [] }
    for cnf in all_my_cnf:
        data["data"].append({"{#NAME}": cnf[1:-4]})
    print json.dumps(data,indent=4)

# 帮助
def usage(all_my_cnf):
    print "Usage: %s discovery" % sys.argv[0]
    for cnf in all_my_cnf:
        print "     : %s %s" % (sys.argv[0], cnf[1:-4])
    os._exit(1)

# 获取延迟时间
def get_lag(cnf):
    mysql_cmd = [ "mysql", "--defaults-file=%s" % ( "/var/lib/zabbix/" + cnf ), "-N", "-e"]
    select    = "SELECT UNIX_TIMESTAMP()-UNIX_TIMESTAMP(ts) from oc.timestamp\G"
    mysql_cmd.append(select)
    FNULL = open(os.devnull, 'w')
    try:
        out = subprocess.check_output(mysql_cmd,stderr=FNULL)
        out = out.split('\n')[1]
    except Exception as e:
        out = 9999

    print out
    
if __name__ == '__main__':
    all_my_cnf=get_my_cnf()

    if len(sys.argv) == 2:
        cnf = "." + str(sys.argv[1]) + ".cnf"
        if str(sys.argv[1]) == "discovery":
            discovery(all_my_cnf)
        elif cnf in all_my_cnf:
            get_lag(cnf)
    else:
        usage(all_my_cnf)
