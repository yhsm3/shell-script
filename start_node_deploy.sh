#!/bin/bash
set -e

# fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"
# fonts color

UnzipPath="/tmp/node_develop/"

query(){
    # 只允许输入y/n，否则循环提示输入
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}


echo -e "${Green}开始进行边缘节点的离线部署${Font}"
echo -e "${Red}请注意：主机名不是 localhost，且不不能包含下划线、小数点、大写字母${Font}"
echo -e "${Yellow}当前主机名为 $(hostname) ${Font}"
choose=$(query "是否需要修改[y/n]:")
if [[ $choose == "y" ]];then
choose="null"
while [[ $choose != "y" ]]
do
    read -r -p "请输入主机名：" HOSTNAME
    read -r -p "（请确认）主机名${HOSTNAME}是否满足需求[y/n]：" choose
done
hostnamectl set-hostname $HOSTNAME
hostnamectl status
fi

init(){
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld

    # 关闭 SeLinux
    if setenforce 0; then echo "" else echo ""; fi
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

    # 关闭 swap
    swapoff -a
    yes | cp /etc/fstab /etc/fstab_bak
    cat /etc/fstab_bak |grep -v swap > /etc/fstab

    rm -rf /etc/sysctl.conf
    touch /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1"  >> /etc/sysctl.conf
    # 执行命令以应用
    sysctl -p
}

# 初始化edgecore的环境
init

# 部署docker
sh docker_deploy.sh

# 部署edgecore
sh edgecore_deploy.sh

# 部署frpc
sh frpc_deploy.sh

rm -rf $UnzipPath

pwd
echo -e "${Green}部署结束${Font}"
