#!/bin/bash

Ver="5.5.40v3"
sudo docker build -t by-mysql:${Ver} .
sudo docker save by-mysql:${Ver} | gzip > by-mysql_${Ver}.gz
