#!/bin/bash

set -e

# fonts color
Green="\033[32m"
Red="\033[31m"
Font="\033[0m"
# fonts colo

KubeEdgePath="/etc/kubeedge/"
KubeEdgeConfPath=$KubeEdgePath"config/"
KubeEdgeConfYaml=$KubeEdgeConfPath"edgecore.yaml"
EdgecoreService="/etc/systemd/system/edgecore.service"
DftCertPort="10002"
DftStreamPort="10004"

query(){
    local choose
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read -r -p $1 choose
    done
    echo $choose
}

install_edgecore(){
    # podSandboxImage
    edge_arch=`arch`
    case "$edge_arch" in
        aarch64) kubeedge_arch="arm64" ke_pause_image=harmonycloud.io/edge-arm64/pause:3.1-arm64;;
        x86_64) kubeedge_arch="amd64" ke_pause_image=harmonycloud.io/edge-amd64/pause:3.1;;
        *) echo "不支持该架构: "$edge_arch; exit -1;;
    esac

    file_name=$(pwd)/tar/kubeedge-v1.6.1-linux-"$kubeedge_arch".tar.gz
    dir_name=kubeedge-v1.6.1-linux-$kubeedge_arch
    checksum_name=$(pwd)/tar/checksum_${dir_name}.tar.gz.txt
    check_result=0

    if [ ! -d "$KubeEdgePath" ]; then
        mkdir $KubeEdgePath
    fi

    if [ ! -d "$KubeEdgeConfPath" ]; then
        mkdir $KubeEdgeConfPath
    fi

    if [ -e "$file_name" ] && [ -e "$checksum_name" ]; then
        checksum=`sha512sum $file_name | awk '{print $1}'`
        rightsum=`cat $checksum_name`
        if [ $checksum == $rightsum ]; then
            check_result=1
            echo "校验成功，开始安装edgecore..."
        else
            echo -e "${Red}校验失败，请检查kubeedge压缩包是否正确${Font}"
            exit -1
        fi
    fi

    # cloudcore ip and port
    choose="null"
    while [[ $choose != "y" ]]
    do
        read -r -p "请输入cloudcore ip and port(for edgecore to connect), 格式: 192.168.1.10:10000: " cloudcore_ipport
        read -r -p "（请确认）cloudcore ip and port为：${cloudcore_ipport} [y/n] " choose
    done

    # cert port of cloudcore
    choose=$(query "cert_port_of_cloudcore默认为${DftCertPort}，是否需要修改[y/n]: ")
    if [[ $choose == "y" ]]
    then
        choose="null"
        while [[ $choose != "y" ]]
        do
          read -r -p "请输入cert_port_of_cloudcore: " cert_port
          read -r -p "（请确认）cert_port为：${cert_port} [y/n] " choose
        done
    else
        cert_port=$DftCertPort
    fi

    # edgeStream server port
    choose=$(query "edgeStream_server_port默认为${DftStreamPort}，是否需要修改[y/n]: ")
    if [[ $choose == "y" ]]
    then
        choose="null"
        while [[ $choose != "y" ]]
        do
          read -r -p "请输入edgeStream_server_port: " edgestream_port
          read -r -p "（请确认）edgeStream_server_port为：${edgestream_port} [y/n] " choose
        done
    else
        edgestream_port=$DftStreamPort
    fi

    # edgenode_name
    edgenode_name=$(hostname)

    # token
    choose="null"
    while [[ $choose != "y" ]]
    do
        read -r -p "请输入token of cloudcore(which will be checked when edge node connect to cloudcore):" token
        read -r -p "（请确认）token 为：${token} [y/n]:" choose
    done

    # labels
    choose=$(query "是否需要输入node_labels[y/n]:")
    if [[ $choose == "y" ]]
    then
        choose="null"
        while [[ $choose != "y" ]]
        do
          read -r -p "请输入node labels(like harmonycloud.cn/edge=true,a=b,v=m etc): " label
          read -r -p "（请确认）node labels 为：${label} [y/n] " choose
        done
    fi

    # ----------------------------------------------------------------------------------------

    if [[ -z $cloudcore_ipport || -z $token ]]; then
        echo "cloudcore_ipport: $cloudcore_ipport"
        echo "token: $token"
        echo -e "${Red}注意：请确保cloudcore_ipport和token不为空${Font}"
        exit -1
    fi

    echo "cert_port: "$cert_port
    echo "cloudcore_ipport: "$cloudcore_ipport
    echo "edgestream_port: "$edgestream_port
    echo "edgenode_name: "$edgenode_name
    echo "token: "$token

    if systemctl stop edgecore; then echo "edgecore已停止"; else echo "edgecore已停止"; fi

    # 分别获取ip->ip_info[0] 和 port -> ip_info[1]
    ip_info=(${cloudcore_ipport//:/ })
    cert_ipport="https:\/\/"${ip_info[0]}":"$cert_port

    if [ $check_result -eq 1 ]; then
        tar -xvzf $file_name -C $KubeEdgePath
        rm -f $KubeEdgePath"edgecore"
        cp $KubeEdgePath$dir_name/edge/edgecore $KubeEdgePath
        $KubeEdgePath/edgecore --defaultconfig > $KubeEdgeConfYaml
        sed -i "s/httpServer.*/httpServer: $cert_ipport/" $KubeEdgeConfYaml
        sed -i "47 s/server:.*/server: ${ip_info[0]}:$edgestream_port/" $KubeEdgeConfYaml
        sed -i "24,35 s/server:.*/server: $cloudcore_ipport/" $KubeEdgeConfYaml
        sed -i "38 s/enable:.*/enable: false/" $KubeEdgeConfYaml
        sed -i "44 s/enable:.*/enable: true/" $KubeEdgeConfYaml
        sed -i "s/token:.*/token: $token/" $KubeEdgeConfYaml
        sed -i "s/devicePluginEnabled:.*/devicePluginEnabled: true/" $KubeEdgeConfYaml
        sed -i "s/mqttMode:.*/mqttMode: 0/" $KubeEdgeConfYaml
        sed -i "s/hostnameOverride:.*/hostnameOverride: $edgenode_name/" $KubeEdgeConfYaml
        if [[ ! -z $ke_pause_image ]]; then
          sed -i "s|podSandboxImage:.*|podSandboxImage: $ke_pause_image|" $KubeEdgeConfYaml
        fi
        label=`echo $label | sed -e 's/=/: /g'`
        sed -i "71a\    labels: {$label}" $KubeEdgeConfYaml
    fi

    # create edgecore.service
    rm -rf $EdgecoreService
    touch $EdgecoreService
    cat>$EdgecoreService<<EOF
[Unit]
Description=edgecore.service

[Service]
Type=simple
ExecStart=/etc/kubeedge/edgecore
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

start_edgecore(){
    start_num=0
    while true; do
        status=$(sudo systemctl show --property ActiveState edgecore)
        if [ $status = "ActiveState=active" ]; then
            echo "edgecore正在运行..."
            break
        else
            if [ $start_num -eq 3 ]; then
                echo -e "${Green}====================================================================${Font}"
                echo -e "${Green}启动失败,请检查！可以考虑尝试卸载edgecore，重新安装:${Font}"
                echo -e "${Red}systemctl stop edgecore${Font}"
                echo -e "${Red}rm -rf ${KubeEdgePath}${Font}"
                echo -e "${Red}rm -rf ${EdgecoreService}${Font}"
                echo -e "${Green}执行以上命令之后重新运行脚本:${Font}"
                echo -e "${Red}sh edgecore_deploy.sh${Font}"
                echo -e "${Red}sudo systemctl status edgecore 查看服务是否启动${Font}"
                echo -e "${Green}====================================================================${Font}"
                exit -1
            else
                echo "尝试启动edge..."
                sudo systemctl start edgecore
            fi
            let start_num+=1
        fi
    done
    systemctl status edgecore
    systemctl enable edgecore
}

# -------------------------------start-------------------------------

if /etc/kubeedge/edgecore --version ; then
    KeVer=`/etc/kubeedge/edgecore --version`
    KeVer=`echo $KeVer | awk '{print $2}' | echo $KeVer | sed 's/.*v\([0-9.]*\).*/\1/g'`
    if [ "$(echo "${KeVer}" 1.5.1 | awk '{print($1>=$2)?1:0}')" -eq 1 ]
    then
        echo -e "${Green}当前KubeEdge版本为：${KeVer}, 符合要求${Font}"
        start_edgecore
    else
        if systemctl stop edgecore; then echo "已停止edgecore"; else echo "已停止edgecore"; fi
        rm -rf $KubeEdgePath
        rm -rf $EdgecoreService
        install_edgecore
        start_edgecore
    fi
else
    install_edgecore
    start_edgecore
fi

echo -e "${Green}当前已经加载fluent-bit:v1.5、node-exporter:v0.18.1镜像，如有需要可以自行配置${Font}"

pwd