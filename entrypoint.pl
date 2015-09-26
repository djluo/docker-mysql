#!/usr/bin/perl
# vim:set et ts=2 sw=2:

# Author : djluo
# version: 2.0(20150107)
#
# 初衷: 每个容器用不同用户运行程序,已方便在宿主中直观的查看.
# 需求: 1. 动态添加用户,不能将添加用户的动作写死到images中.
#       2. 容器内尽量不留无用进程,保持进程树干净.
# 问题: 如用shell的su命令切换,会遗留一个su本身的进程.
# 最终: 使用perl脚本进行添加和切换操作. 从环境变量User_Id获取用户信息.

use Cwd;
use strict;
#use English '-no_match_vars';

my $uid = 1000;
my $gid = 1000;
my $pwd = cwd();

$uid = $gid = $ENV{'User_Id'} if $ENV{'User_Id'} =~ /\d+/;

unless (getpwuid("$uid")){
  system("/usr/sbin/useradd", "-U", "-u $uid", "-m", "docker");
}

unless( -f "/etc/mysql/my.cnf"){
  system("cp", "/my.cnf",     "/etc/mysql/my.cnf");
  system("cp", "/debian.cnf", "/etc/mysql/debian.cnf");

  system("sed", "-i", "s%/MYSQL%$pwd%", "/etc/mysql/my.cnf");
  system("sed", "-i", "s%/MYSQL%$pwd%", "/etc/mysql/debian.cnf");
}
system("/init.sh") if ( ! -f "./data/init_complete" );

my @dirs = ("log", "logs", "data");
foreach my $dir (@dirs) {
  if ( -d $dir && (stat($dir))[4] != $uid ){
    system("chown docker.docker -R " . $dir);
  }
}

system("rm", "-f", "/run/crond.pid") if ( -f "/run/crond.pid" );
system("/usr/sbin/cron");

my $min1 = int(rand(60));
my $hour = int(rand(5));

my $min2 = $min1;
$min2 = $min1 - 3 if $min1 > 3;

system("mkdir", "-m", "700", "./backup") unless ( -d "./backup" );
open (CRON,"|/usr/bin/crontab") or die "crontab error?";
print CRON ("$min2 $hour * * * (cd $pwd; /xtrab.sh delete >./backup/stdout.log 2>./backup/stderr.log)\n");
print CRON ("$min1 $hour * * * (cd $pwd; /xtrab.sh backup >./backup/stdout.log 2>./backup/stderr.log)\n");

if( $ENV{'RSYNC_PASSWORD'} ){
  my $ip   = $ENV{'backup_ip'};
  my $dest = $ENV{'backup_dest'}."_".$ENV{'HOSTNAME'};
  my $rsync_hour = $hour + 1;
  my $port="2873";
     $port="$ENV{'RSYNC_PORT'}" if ( $ENV{'RSYNC_PORT'} );
  my $rsync_opts = "/usr/bin/rsync --del --port=$port -al --password-file=/rsync.pass";

  my $umask = umask;
  umask 0277;
  open (PW,'>', '/rsync.pass') or die "$!";
  print PW $ENV{'RSYNC_PASSWORD'};
  close(PW);
  umask $umask;

  print CRON ("$min1 $rsync_hour * * * ($rsync_opts $pwd/backup/ docker@". $ip ."::backup/$dest/)\n");
}

close(CRON);

# 切换当前运行用户,先切GID.
#$GID = $EGID = $gid;
#$UID = $EUID = $uid;
$( = $) = $gid; die "switch gid error\n" if $gid != $( ;
$< = $> = $uid; die "switch uid error\n" if $uid != $< ;

$ENV{'HOME'} = "/home/docker";
my @cmd = @ARGV;
my $extra_cnf = "$pwd/extra-my.cnf";
splice @cmd, 1, 0, "--defaults-extra-file=$extra_cnf" if ( -f "$extra_cnf" );

exec(@cmd);
