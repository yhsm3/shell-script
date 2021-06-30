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
UnzipFrpcPath=${UnzipPath}"frpc-0.37.0-linux-${arch}"


config(){
cat > config << EOF
[common]
server_addr = frp.freefrp.net
server_port = 7000
token = freefrp.net
[web1_29812893]
type = tcp
local_ip = 10.10.102.84
local_port = 443
remote_port = 36278
EOF
}



frpc_script(){
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# fonts color
Green="\033[32m"
Red="\033[31m"
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

FILE_NAME=frp-${FRP_VERSION}-linux-${PLATFORM}


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
    exit -1
fi


# 判断 frpc 进程并 kill
while ! test -z "$(ps -A | grep -w ${FRP_NAME})"; do
    FRPCPID=$(ps -A | grep -w ${FRP_NAME} | awk 'NR==1 {print $1}')
    kill -9 $FRPCPID
done

#

mkdir -p ${FRP_PATH}
#wget -P ${WORK_PATH} https://ghproxy.com/https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FILE_NAME}.tar.gz -O ${FILE_NAME}.tar.gz && \
#tar -zxvf /root/${FILE_NAME}.tar.gz && \
if [ ! -d "$UnzipPath" ]; then
        mkdir $UnzipPath
fi
if [ -d $UnzipFrpcPath ]; then
    rm -rf $UnzipFrpcPath
fi

tar -zxvf "$(pwd)"/tar/${FILE_NAME}.tar.gz -C $UnzipPath

cp ${UnzipPath}${FILE_NAME}/${FRP_NAME} ${FRP_PATH}
rm -rf ${UnzipPath}${FILE_NAME}

local choose
while [[ $choose != "y" ]]
do
    read -r -p "请输入提供穿透服务的服务器IP：" server_address
    read -r -p "请输入提供穿透服务的服务器端口：" server_port
    read -r -p "（请确认）穿透服务的服务[ip:port]为：${server_address}:${server_port} [y/n] " choose
done


cat >${FRP_PATH}/${FRP_NAME}.ini <<EOF
[common]
server_address = ${server_address}
server_port = ${server_port}

[ssh-#unique-id#]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 0
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

sudo systemctl daemon-reload
sudo systemctl start ${FRP_NAME}
sudo systemctl enable ${FRP_NAME}

rm -rf $UnzipFrpcPath
}



install_frpc_offline(){
    start_num=0
    while true; do
        if [ -f "/usr/local/frp/frpc" ] && [ -f "/usr/local/frp/frpc.ini" ] && [ -f "/lib/systemd/system/frpc.service" ] && /usr/local/frp/frpc -v
        then
            echo "frpc安装成功"
            break
        else
            if [ $start_num -eq 3 ]; then
                echo "frpc安装失败，请检查！" >&2
                exit -1
            else
                echo -e "${Green}尝试安装frpc...${Font}"

                # 卸载frpc
                if sudo systemctl status frpc;
                then
                  sudo systemctl stop frpc
                fi

                rm -rf /usr/local/frp
                rm -rf /lib/systemd/system/frpc.service
                echo -e "${Green}============================${Font}"
                echo -e "${Green}卸载成功,frpc相关文件已清理完毕!${Font}"
                echo -e "${Green}============================${Font}"
                sudo systemctl daemon-reload

                # 安装frpc
                frpc_script
            fi
            let start_num+=1
        fi
    done
}

start_frpc(){
    start_num=0
    while true; do
        sleep 2
        status=$(sudo systemctl show --property ActiveState frpc)
        if [ $status = "ActiveState=active" ]; then
          echo "frpc正在运行..."
          break
        else
              if [ $start_num -eq 3 ]; then
                  echo -e "${Green}====================================================================${Font}"
                  echo -e "${Green}启动失败,请先检查 /usr/local/frp/frpc.ini文件,确保提供穿透服务的服务器IP和端口正确!${Font}"
                  echo -e "${Red}vi /usr/local/frp/frpc.ini${Font}"
                  echo -e "${Green}修改完毕后执行以下命令重启服务:${Font}"
                  echo -e "${Red}sudo systemctl restart frpc ${Font}"
                  echo -e "${Red}sudo systemctl status frpc 查看服务是否启动${Font}"
                  echo -e "${Green}====================================================================${Font}"
                  exit -1
              else
                  echo "尝试启动frpc..."
                  sudo systemctl restart frpc
              fi
              let start_num+=1
        fi
    done
    sudo systemctl status frpc
    echo -e "${Green}启动成功${Font}"
    echo -e "${Green}====================================================================${Font}"
}

# -------------------------------deploy_docker-------------------------------

if [ -f "/usr/local/frp/frpc" ] && [ -f "/usr/local/frp/frpc.ini" ] && [ -f "/lib/systemd/system/frpc.service" ]
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
        fi
    fi
    start_frpc
else
    install_frpc_offline
    start_frpc
fi
pwd
