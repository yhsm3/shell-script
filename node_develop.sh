#!/bin/bash
set -e

# fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
# fonts color

# -------------------------------适配不同linux发行版 begin------------------------------
# centos7上可运行，其他发行版未测试
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

    # 首先搜索已经安装的docker安装包
    yum list installed|grep docker

    ## 分别删除安装包
    yum remove -y docker-ce-cli.x86_64

    ## 删除docker存储目录
    rm -rf /var/lib/docker
    rm -rf /var/lib/dockershim
    rm -rf /var/lib/docker-engine
    rm -rf /etc/docker
    rm -rf /run/docker
}
check_docker_status_command(){
    systemctl show --property ActiveState docker
}
start_docker_command(){
    sudo systemctl start docker
}
docker_status_command(){
    systemctl status docker
}
docker_enable_command(){
    systemctl enable docker
}
install_local_rpm(){
    yum -y install *.rpm
}


stop_service_frpc_command(){
    sudo systemctl stop frpc
}
daemon_reload_command(){
    sudo systemctl daemon-reload
}
start_frpc_command(){
    sudo systemctl start frpc
}
check_frpc_status_command(){
    systemctl show --property ActiveState frpc
}

frpc_status_command(){
    systemctl status frpc
}
# -------------------------------适配不同linux发行版 end-------------------------------


######################################################################################

start_docker(){
    start_num=0
    while true; do
        status=$(check_docker_status_command)
        if [ $status = "ActiveState=active" ]; then
          echo "docker正在运行..."
          break
        else
              if [ $start_num -eq 3 ]; then
                  echo "docker启动失败，请检查！" >&2
                  exit 1
              else
                  echo "尝试启动docker..."
                  start_docker_command
              fi
              let start_num+=1
        fi
    done
    docker_status_command
}

install_docker_offline(){
    # 在有网络的环境下下载离线软件到指定目录
    # sudo yum install --downloadonly --downloaddir=~/docker19.03-package docker-ce-19.03.8-3.el7 docker-ce-cli-19.03.8-3.el7

    cd ~/docker-19.03

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
                  install_local_rpm
                  # yum -y install *.rpm
              fi
              let start_num+=1
        fi
    done
    docker_enable_command
}

frpc_script(){
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
# fonts color

# variable
WORK_PATH=$(dirname $(readlink -f $0))
FRP_NAME=frpc
FRP_VERSION=0.37.0
FRP_PATH=/usr/local/frp

if [ $(uname -m) = "x86_64" ]; then
    export PLATFORM=amd64
else
  if [ $(uname -m) = "aarch64" ]; then
    export PLATFORM=arm64
  fi
fi


FILE_NAME=frp_${FRP_VERSION}_linux_${PLATFORM}


# 判断是否安装 frpc
if [ -f "/usr/local/frp/${FRP_NAME}" ] || [ -f "/usr/local/frp/${FRP_NAME}.ini" ] || [ -f "/lib/systemd/system/${FRP_NAME}.service" ];then
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${RedBG}当前已退出脚本.${Font}"
    echo -e "${Green}检查到服务器已安装${Font} ${Red}${FRP_NAME}${Font}"
    echo -e "${Green}请手动确认和删除${Font} ${Red}/usr/local/frp/${Font} ${Green}目录下的${Font} ${Red}${FRP_NAME}${Font} ${Green}和${Font} ${Red}/${FRP_NAME}.ini${Font} ${Green}文件以及${Font} ${Red}/lib/systemd/system/${FRP_NAME}.service${Font} ${Green}文件,再次执行本脚本.${Font}"
    echo -e "${Green}参考命令如下:${Font}"
    echo -e "${Red}rm -rf /usr/local/frp/${FRP_NAME}${Font}"
    echo -e "${Red}rm -rf /usr/local/frp/${FRP_NAME}.ini${Font}"
    echo -e "${Red}rm -rf /lib/systemd/system/${FRP_NAME}.service${Font}"
    echo -e "${Green}=========================================================================${Font}"
    exit 2
fi


# 判断 frpc 进程并 kill
while ! test -z "$(ps -A | grep -w ${FRP_NAME})"; do
    FRPCPID=$(ps -A | grep -w ${FRP_NAME} | awk 'NR==1 {print $1}')
    kill -9 $FRPCPID
done

mkdir -p ${FRP_PATH}
#wget -P ${WORK_PATH} https://ghproxy.com/https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FILE_NAME}.tar.gz -O ${FILE_NAME}.tar.gz && \
tar -zxvf /root/${FILE_NAME}.tar.gz && \
mv ${FILE_NAME}/${FRP_NAME} ${FRP_PATH}

cat >${FRP_PATH}/${FRP_NAME}.ini <<EOF
[common]
server_addr = frp.freefrp.net
server_port = 7000
token = freefrp.net

[web1_${RANDOM}]
type = tcp
local_ip = ${LOCAL_IP}
local_port = 443
remote_port = 36278
#custom_domains = yourdomain${RANDOM}.com
EOF

cat >/lib/systemd/system/${FRP_NAME}.service <<EOF
[Unit]
Description=Frp Server Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frp/${FRP_NAME} -c /usr/local/frp/${FRP_NAME}.ini

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sudo systemctl start ${FRP_NAME}
sudo systemctl enable ${FRP_NAME}
#rm -rf ${WORK_PATH}/${FILE_NAME}.tar.gz ${WORK_PATH}/${FILE_NAME} ${FRP_NAME}_linux_install.sh

echo -e "${Green}====================================================================${Font}"
echo -e "${Green}安装成功,请先修改 ${FRP_NAME}.ini 文件,确保格式及配置正确无误!${Font}"
echo -e "${Red}vi /usr/local/frp/${FRP_NAME}.ini${Font}"
echo -e "${Green}修改完毕后执行以下命令重启服务:${Font}"
echo -e "${Red}sudo systemctl restart ${FRP_NAME}${Font}"
echo -e "${Green}====================================================================${Font}"
}

install_frpc_offline(){
    start_num=0
    while true; do
        if [ -f "/usr/local/frp/frpc" ] && /usr/local/frp/frpc -v ; then
            echo "frpc安装成功"
            break
        else
            if [ $start_num -eq 3 ]; then
                echo "frpc安装失败，请检查！" >&2
                exit 1
            else
                echo -e "${Yellow}尝试安装frpc...${Font}"

                # 卸载frpc
                if systemctl status frpc;
                then
                  stop_service_frpc_command
                fi

                rm -rf /usr/local/frp
                rm -rf /lib/systemd/system/frpc.service
                daemon_reload_command
                echo -e "${Green}============================${Font}"
                echo -e "${Green}卸载成功,frpc相关文件已清理完毕!${Font}"
                echo -e "${Green}============================${Font}"

                # 安装frpc
                # chmod +x frpc_linux_install.sh && ./frpc_linux_install.sh
                frpc_script
            fi
            let start_num+=1
        fi
    done
}

start_frpc(){
    start_num=0
	while true; do
	    status=$(check_frpc_status_command)
	    if [ $status = "ActiveState=active" ]; then
		    echo "frpc正在运行..."
		    break
	    else
            if [ $start_num -eq 3 ]; then
                echo "frpc启动失败，请检查！" >&2
                exit 1
            else
                echo "尝试启动frpc..."
                start_frpc_command
            fi
            let start_num+=1
	    fi
	done
    frpc_status_command
    echo -e "${Green}启动成功${Font}"
    echo -e "${Green}====================================================================${Font}"
}

deploy_frpc(){
    if [ -f "/usr/local/frp/frpc" ] || [ -f "/usr/local/frp/frpc.ini" ] || [ -f "/lib/systemd/system/frpc.service" ]
    then
        echo -e "${Green}=========================================================================${Font}"
        local_frp_version=$(/usr/local/frp/frpc -v)
        echo -e "${Green}检查到服务器已安装frpc, 版本为：${local_frp_version} ${Font} ${Red}frpc${Font}"

        # 判断版本号是否满足需求
        if [ "$(echo "${local_frp_version}" 0.37.0 | awk '{print($1>=$2)?1:0}')" -eq 1 ]
        then
            echo -e "${Green}当前frpc版本符合要求${Font}"
        else 
            choose=$(query "当前frpc版本为：${local_frp_version}，版本不匹配可能导致出错，是否重新安装满足需求frpc版本[y/n]:")
            if [[ $choose == "y" ]]
            then
                install_frpc_offline   
                start_frpc
            fi
        fi
    else
      install_frpc_offline
      start_frpc
    fi
}

input_ip(){
    read -r -p "请输入本机ip：" LOCAL_IP
    read -r -p "本机ip为：${LOCAL_IP} [y/n] " choose
    
    while [[ $choose != "y" ]]
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
    
    systemctl daemon-reload
    systemctl restart docker
    systemctl status docker
}

query(){
    # 只允许输入y/n，否则循环提示输入
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}

deploy_docker(){
    if docker -v
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
    echo -e "${Green}开始进行边缘节点的在线部署${Font}"
    ###
}

develop_offline(){
    echo -e "${Green}开始进行边缘节点的离线部署${Font}"
    deploy_docker
    # develop_edgecore

    deploy_frpc
}

# ------------------------------------------------------------------

# -------------------------------main-------------------------------

main(){
    LOCAL_IP=$(input_ip)
    export LOCAL_IP
    choose=$(query "请选择边缘节点部署方式,是否在线部署[y/n]:")

    if [[ $choose == "y" ]]
    then
        develop_online
    else 
        develop_offline
    fi
}

main