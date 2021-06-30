#!/bin/bash
set -e

# fonts color
Green="\033[32m"
Red="\033[31m"
Font="\033[0m"
# fonts color

arch=$(arch)
case "$arch" in
    aarch64) arch="arm64";;
    x86_64) arch="amd64";;
    *) echo "不支持该架构: "$arch; exit -1;;
esac
UnzipPath="/tmp/node_develop/"
UnzipDockerPath=${UnzipPath}"docker-19.03-linux-${arch}"


pwd=$(pwd)

# -------------------------------适配不同linux发行版 begin------------------------------
# centos7上可运行，其他发行版未测试

uninstall_docker(){
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

    ## 分别删除安装包
    sudo yum remove -y docker-ce-cli."$(arch)"

    ## 删除docker存储目录
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/dockershim
    sudo rm -rf /var/lib/docker-engine
    sudo rm -rf /etc/docker
}

install_local_rpm(){
    sudo yum -y install "${UnzipDockerPath}/"*.rpm
}
# -------------------------------适配不同linux发行版 end-------------------------------



query(){
    # 只允许输入y/n，否则循环提示输入
    local choose
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}

install_docker_offline(){
    arch=$(arch)
    case "$arch" in
        aarch64) arch="arm64";;
        x86_64) arch="amd64";;
        *) echo "不支持该架构: "$arch; exit -1;;
    esac

    # docker-19.03-linux-arm64
    if [ ! -d "$UnzipPath" ]; then
        mkdir $UnzipPath
    fi
    if [ -d $UnzipDockerPath ]; then
        rm -rf $UnzipDockerPath
    fi

    tar -zxvf ${pwd}/tar/docker-19.03-linux-${arch}.tar.gz -C $UnzipPath

    start_num=0
    while true; do
        if docker -v ; then
          echo "docker安装成功"
          break
        else
              if [ $start_num -eq 3 ]; then
                  echo "docker安装失败，请检查！" >&2
                  exit -1
              else
                  echo "尝试安装docker..."
                  install_local_rpm
              fi
              let start_num+=1
        fi
    done
    rm -rf $UnzipDockerPath
}

start_docker(){
    start_num=0
    while true; do
        status=$(sudo systemctl show --property ActiveState docker)
        if [ $status = "ActiveState=active" ]; then
          echo "docker正在运行..."
          break
        else
              if [ $start_num -eq 3 ]; then
                  echo "docker启动失败，请检查！" >&2
                  exit -1
              else
                  echo "尝试启动docker..."
                  sudo systemctl start docker
              fi
              let start_num+=1
        fi
    done
    systemctl status docker
}


# -------------------------------install docker-------------------------------
if docker -v;
# 环境中存在docker
then 
    # Docker version 19.03.8, build afacb8b
    # 使用正则表达式获取版本号
    version=$(docker -v | sed 's/.*sion \([0-9.]*\).*/\1/g')

    # 判断版本号是否满足需求
    if [ "$(echo "${version}" 19.03 | awk '{print($1>=$2)?1:0}')" -eq 1 ]
    then
        echo -e "${Green}当前docker版本为：${version}, 符合要求${Font}"
    else 
        # docker版本不满足需求时，询问是否安装满足需求的docker版本
        choose="null"
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

# -------------------------------configure_docker-------------------------------

docker_folder="/etc/docker"

if [ ! -d $docker_folder ]; then
    mkdir -p $docker_folder
fi

cd ${docker_folder}

file="/etc/docker/daemon.json"
if [ -f $file ]; then
    echo -e "${Green}/etc/docker/daemon.json文件已存在，该文件将重命名为daemon.json+TIME${Font}"
    time=$(date "+%Y-%m-%d_ %H:%M:%S")
    mv daemon.json "daemon.json+${time}"
else
    touch daemon.json
fi

read -r -p "是否需要配置harbor仓库地址[y/n]:" choose
while [[ $choose != "y" && $choose != "n" ]]
do
    read -r -p "是否需要配置harbor仓库地址[y/n]:" choose
done

if [[ $choose == "y" ]]
then
    read -r -p "请输入harbor仓库地址[ip:port]: " HARBOR_IP
    read -r -p "harbor仓库地址为：${HARBOR_IP} [y/n] " choose

    while [[ $choose != "y" ]]
    do
        read -r -p "请输入harbor仓库地址[ip:port]: " HARBOR_IP
        read -r -p "harbor仓库地址为：${HARBOR_IP} [y/n] " choose
    done

    cat >daemon.json<<EOF
{
    "insecure-registries": ["${HARBOR_IP}"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    }
}
EOF

else   

    cat >daemon.json<<EOF
{
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    }
}
EOF
fi
cd -
start_docker
docker -v

docker load -i "`pwd`"/tar/edge-${arch}-images.tar
PAGESIZE=`getconf PAGESIZE`
if [ $PAGESIZE -eq 6114 ]; then
    docker rmi harmonycloud.io/edge-amd64/fluent-bit:v1.5-${arch}
    docker load -i "`pwd`"/tar/fluent-bit-arm64-64-bb.tar
fi
pwd