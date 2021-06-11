#!/bin/bash

# echo -e "\033[34;1m 蓝色字体 \033[0m"
# echo -e "\033[31;1m 红色字体 \033[0m"

set -e

# -------------------------------适配不同linux发行版 begin------------------------------
# centos7上可运行，其他发行版未测试

start_docker(){
    start_num=0
	while true; do
	    status=$(systemctl show --property ActiveState docker)
	    if [ $status = "ActiveState=active" ]; then
		    echo "docker正在运行..."
		    break
	    else
            if [ $start_num -eq 3 ]; then
                echo "docker启动失败，请检查！" >&2
                exit 1
            else
                echo "尝试启动docker..."
                systemctl start docker
            fi
            let start_num+=1
	    fi
	done
    systemctl status docker
}

install_docker_offline(){
    # 在有网络的环境下下载离线软件到指定目录
    # sudo yum install --downloadonly --downloaddir=~/docker19.03-package docker-ce-19.03.8-3.el7 docker-ce-cli-19.03.8-3.el7

    cd ~/docker19.03-package

    start_num=0
	while true; do
	    if docker -v ; then
		    echo "docker安装成功"
		    break
	    else
            if [ $start_num -eq 3 ]; then
                echo "docker安装失败，请检查！" >&2
                exit 1
            else
                echo "尝试安装docker..."
                yum -y install *.rpm
            fi
            let start_num+=1
	    fi
	done
    systemctl enable docker
}

uninstall_docker(){
    yum remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine
}
# -------------------------------适配不同linux发行版 end-------------------------------

input_ip(){
    read -r -p "请输入本机ip：" LOCAL_IP
    read -r -p "本机ip为：${LOCAL_IP} [y/n] " choose
    
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read -r -p "请输入本机ip：" LOCAL_IP
        read -r -p "本机ip为：${LOCAL_IP} [y/n] " choose
    done

    echo ${LOCAL_IP}
}

configure_docker(){
    cd /etc/docker
    file="/etc/docker/daemon.json"
    if [ -f $file ]; then
        echo -e "\033[34;1m /etc/docker/daemon.json文件已存在，该文件将重命名为daemon.json+TIME \033[0m"
        time=$(date "+%Y-%m-%d_ %H:%M:%S")
        mv daemon.json "daemon.json+${time}"
    else
        touch daemon.json
    fi

    choose=$(query "是否需要配置harbor仓库地址[y/n]:")

    if [[ $choose == "y" ]]
    then
        read -r -p "请输入harbor仓库地址[ip:port]: " HARBOR_IP

        cat >daemon.json<<EOF
{
  # 你的Harbor地址
  "insecure-registries": ["${HARBOR_IP}"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
}
EOF

    else   

        cat >daemon.json<<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
}
EOF

    fi
    
    systemctl daemon-reload
    systemctl restart docker
}

query(){
    # 只允许输入y/n，否则循环提示输入
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}

develop_docker(){
    if docker -v
    # 环境中存在docker
    then 
        # Docker version 19.03.8, build afacb8b
        # 使用正则表达式获取版本号
        version=$(docker -v | sed 's/.*sion \([0-9.]*\).*/\1/g')

        # 判断版本号是否满足需求
        if [ "$(echo "${version}" 19.03 | awk '{print($1>=$2)?1:0}')" -eq 1 ]
        then
            echo -e "\033[34;1m当前docker版本为：${version}, 符合要求 \033[0m"
        else 
            # docker版本不满足需求时，询问是否安装满足需求的docker版本
            choose=$(query "当前docker版本为：${version}，版本不匹配可能导致出错，是否重新安装满足需求docker版本[y/n]:")
            if [[ $choose == "y" ]]
            then
                uninstall_docker
                install_docker_offline
            fi
        fi    
    # 环境中不存在docker
    else 
        install_docker_offline
    fi
    start_docker
    configure_docker
}

develop_online(){
    echo -e "\033[34;1m开始进行边缘节点的在线部署 \033[0m"
    # 
}

develop_offline(){
    echo -e "\033[34;1m开始进行边缘节点的离线部署 \033[0m"
    develop_docker
    
}

# ------------------------------------------------------------------

# -------------------------------main-------------------------------

main(){
    choose=$(query "请选择边缘节点部署方式,是否在线部署[y/n]:")

    if [[ $choose == "y" ]]
    then
        develop_online
    else 
        develop_offline
    fi
}

LOCAL_IP=$(input_ip)

main