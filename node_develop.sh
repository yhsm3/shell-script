#!/bin/sh

# echo -e "\033[34;1m 蓝色字体 \033[0m"
# echo -e "\033[31;1m 红色字体 \033[0m"

set -e

# -------------------------------适配不同linux发行版 begin------------------------------
# centos7上可运行，其他发行版未测试
start_docker(){
    systctl enable docker
    systctl start docker
    systctl status docker
}

install_docker_local(){
    # 设置 yum repository
    yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

    # 安装并启动 docker
    yum install -y docker-ce-19.03.8 docker-ce-cli-19.03.8 containerd.io
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


query(){
    # 只允许输入y/n，否则循环提示输入
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}

develop_docker(){
    if docker 
    # 环境中存在docker
    then 
        # Docker version 19.03.8, build afacb8b
        # 使用正则表达式获取版本号
        version=$(docker -v | sed 's/.*sion \([0-9.]*\).*/\1/g')

        # 判断版本号是否满足需求
        if [ "$(echo "${version}" 19.03 | awk '{print($1>=$2)?1:0}')" -eq 1 ]
        then
            start_docker
        else 
            # docker版本不满足需求时，询问是否安装满足需求的docker版本
            choose=$(query "当前docker版本为：${version}，版本不匹配可能导致出错，是否重新安装满足需求docker版本[y/n]:")
            if [[ $choose == "y" ]]
            then
                uninstall_docker
                install_docker_local
            fi
        fi    
    # 环境中不存在docker
    else 
        install_docker_local
    fi
    start_docker
}

develop_online(){
    echo -e "\033[34;1m开始进行边缘节点的在线部署 \033[0m"
    # 
}

develop_offline(){
    echo -e "\033[34;1m开始进行边缘节点的离线部署 \033[0m"
    develop_docker
    
}

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

main