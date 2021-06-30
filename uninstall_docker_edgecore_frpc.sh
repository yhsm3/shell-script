#!/bin/bash

    sudo yum remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine

    # 首先搜索已经安装的docker安装包
    # sudo yum list installed|grep docker

    ## 分别删除安装包
    sudo yum remove -y docker-ce-cli."$(arch)"

    ## 删除docker存储目录
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/dockershim
    sudo rm -rf /var/lib/docker-engine
    sudo rm -rf /etc/docker

yum -y install docker

systemctl stop edgecore
rm -rf /etc/kubeedge/
rm -rf /etc/systemd/system/edgecore.service

systemctl stop frpc
rm -rf /usr/local/frp/
rm -rf /lib/systemd/system/frpc.service

systemctl daemon-reload

echo "yes"
echo "no"
