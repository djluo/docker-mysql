#!/bin/bash
# vim:set et ts=2 sw=2:

# Author : djluo

current_dir=`dirname $0`
current_dir=`readlink -f $current_dir`
cd ${current_dir} && export current_dir

registry="docker.xlands-inc.com"
repo=$(dirname   ${current_dir})
repo=$(basename  ${repo})
image=$(basename ${current_dir})
full_image="${registry}/${repo}/${image}"
ver="${1-latest}"

usage() {
  echo "Usage: $0         # building and tag is latest"
  echo "Usage: $0 [x.y.z] # building and tag is x.y.z"
  echo
  exit 127
}

if [ "x$1" == "x-h" -o "x$1" == "x--help" ];then
  usage
fi

cid=0
sudo docker build -t ${full_image}:${ver} . \
  && cid=$(sudo docker images -q ${full_image} | head -1)

#backup="${current_dir}/images/${image}_${ver}_${cid}.gz"
#
#if [ "x$cid" != "x0" ] && [ ! -f $backup ];then
#  sudo docker save ${cid} | gzip > ./images/${image}_${ver}_${cid}.gz
#else
#  echo "$backup exist"
#fi
