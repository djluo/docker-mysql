# 介绍
基于CentOS 7的Oracle Mysql容器。

## 目录结构约定：
约定目的: 与docker无关,自用.

|  目录                         |             用途                                  |
|-------------------------------|---------------------------------------------------|
|/home/coop/appname/mysql/      |主目录,如是和应用同一台设备,那就放到该应用的目录下 |
|/home/coop/appname/mysql/etc/  |配置文件,如my.cnf                                  |
|/home/coop/appname/mysql/log/  |innodb的log                                        |
|/home/coop/appname/mysql/logs/ |慢查询日志/sock文件等                              |
|/home/coop/appname/mysql/data/ |数据主目录                                         |

## 创建镜像：
1. 获取：
<pre>
cd ~
git clone https://github.com/djluo/docker-mysql.git
</pre>
2. 构建镜像（依赖网络,会从Oracle官网下载mysql）：
<pre>
cd ~/docker-mysql
sudo docker build -t mysql   .
sudo docker build -t mysql:1 .
</pre>
3. 启动容器：
<pre>
CID=$(sudo docker run -d -p 3306:3306 mysql)
</pre>
4. 获取初始密码：
<pre>
sudo docker logs $CID
</pre>
5. 测试：
<pre>
sudo docker run -ti --volumes-from $CID --rm mysql mysql -p -e"show databases;"
# or
mysql -h127.0.0.1 -P3306 -p -e"show databases;"
</pre>

## 使用:
1. 目录结构:
<pre>
sudo mkdir -p /home/coop/appname/mysql/{etc,log,logs,data}
</pre>
2. 配置my.cnf：
<pre>
sudo cp ~/docker-mysql/my.cnf /home/coop/appname/mysql/etc/
</pre>
3. 启动:
```shell
cd /home/coop/appname/mysql/
CID=$(sudo docker run -d -p 3306:3306 \
    -v `pwd`/etc/:/mysql/etc/:ro      \
    -v `pwd`/log/:/mysql/log/         \
    -v `pwd`/logs/:/mysql/logs/       \
    -v `pwd`/data/:/mysql/data/       \
    --name appname_db mysql)
```
4. 修改初始密码(可选):
```shell
sudo docker run -ti --volumes-from $CID --rm mysql mysql -p
mysql> grant all privileges on *.* to root@"${CID}"    identified by "new_password";
mysql> grant all privileges on *.* to root@"localhost" identified by "new_password";
mysql> grant all privileges on *.* to root@"127.0.0.1" identified by "new_password";
mysql> flush privileges;
```
5. 导入应用数据库。
