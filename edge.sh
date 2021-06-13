#!/bin/bash

KubeEdgeDownloadURL="https://edgedev.harmonycloud.cn:10443/kubeedge/kubeedge/releases/download/"
KubeEdgePath="/etc/kubeedge/"
KubeEdgeConfPath=$KubeEdgePath"config/"
KubeEdgeConfYaml=$KubeEdgeConfPath"edgecore.yaml"
EdgecoreService="/etc/systemd/system/edgecore.service"
DftCertPort="10002"
DftStreamPort="10004"
DftKeVer="1.5.1"

docker_check()
{
    echo "检查docker......"
    docker &> /dev/null
    if [ $? -eq  0 ]; then
        echo "docker已安装！"
	start_num=0
	while true; do
	    status=`systemctl show --property ActiveState docker`
	    if [ $status = "ActiveState=active" ]; then
		echo "docker正在运行..."
		break
	    else
		let start_num+=1
		if [ $start_num -eq 1 ]; then
		    echo "尝试启动docker..."
		    systemctl start docker
		else
		    echo "docker启动失败，请检查！"
		    exit -1
		fi
	    fi
	done
    else
	echo "请先安装docker环境！"
	exit -1
    fi
}


usage() {
    echo "Usage:"
    echo "./manual_install_edge.sh [-p cert_port] [-i cloudcore_ipport] [-s edgeStream_port] [-n edgenode_name] /
	[-t token] [-v kubeedge_version] [-r vendor_name] [-m model_name] [-c city_name] [-a area_name] /
    [-b branch_name] [-e detect_ip_name] [-k kubeedge_pause_image] [-l label] [-d]"
    echo "Arguments:"
    echo "-p    cert port of cloudcore, default is $DftCertPort"
    echo "-i    cloudcore ip addr and port for edgecore connect, format like: 192.168.1.10:10000"
    echo "-s    edgeStream server port, default 10004"
    echo "-n    edge node name, which will be displayed in k8s cluster, default is hostname of edge node: `hostname`"
    echo "-t    token of cloudcore, which will be checked when edge node connect to cloudcore"
    echo "-v    version of install packages, default is $DftKeVer"
    echo "-r    label of vendor, like huawei, intel, etc"
    echo "-m    label of model, like Ascend310, deepglint, etc"
    echo "-c    label of city, like wuhan, nanjing, etc"
    echo "-a    label of area in city, like tianhe, xuanwu, etc"
    echo "-b    label of branch, like jiangan, huajin, etc"
    echo "-e    label of detect ip name, like eth0, ens0, etc"
    echo "-k    kubeedge pause image, like kubeedge/pause-arm64:3.1"
    echo "-l    other node labels, like harmonycloud.cn/edge: true, etc"
    echo "-d    download install packges from $KubeEdgeDownloadURL, default is off-line install"
    exit -1
}

downfile="false"

while getopts 'p:i:s:n:t:v:r:m:c:a:b:e:k:l:dh' OPT
do
    case $OPT in
    p) cert_port="$OPTARG";;
    i) cloudcore_ipport="$OPTARG";;
    s) edgestream_port="$OPTARG";;
    n) edgenode_name="$OPTARG";;
    t) token="$OPTARG";;
    v) kubeedge_version="$OPTARG";;
    r) vendor="$OPTARG";;
    m) model="$OPTARG";;
    c) city="$OPTARG";;
    a) area="$OPTARG";;
    b) branch="$OPTARG";;
    e) detect_ip="$OPTARG";;
    k) ke_pause_image="$OPTARG";;
    l) label="$OPTARG";;
    d) downfile="true";;
    h) usage;;
    ?) usage;; 
    esac
done

if [[ -z $cloudcore_ipport || -z $token ]]; then
    echo "cloudcore_ipport: $cloudcore_ipport"
    echo "token: $token"
    echo "WARN: please specify necessary args above for edge node"
    usage
fi

if [[ -z $edgestream_port ]]; then
    edgestream_port=$DftStreamPort
    echo "edgeStream server port is not specified, apply default: $edgestream_port"
fi

if [[ -z $edgenode_name ]]; then
    edgenode_name=`hostname`
    echo "edgenode name is not specified, apply hostname: $edgenode_name"
fi

if [[ -z $cert_port ]]; then
    cert_port=$DftCertPort
    echo "cert port is not specified, apply default: $cert_port"
fi

if [[ -z $kubeedge_version ]]; then
    kubeedge_version=$DftKeVer
    echo "kubeedge version is not specified, apply default: $kubeedge_version"
fi

echo "cert_port: "$cert_port
echo "cloudcore_ipport: "$cloudcore_ipport
echo "edgestream_port: "$edgestream_port
echo "edgenode_name: "$edgenode_name
echo "token: "$token
echo "kubeedge_version:"$kubeedge_version

docker_check

systemctl stop edgecore

edge_arch=`arch`
case "$edge_arch" in
    aarch64) kubeedge_arch="arm64";;
    x86_64) kubeedge_arch="amd64";;
    *) echo "不支持该架构: "$edge_arch; exit -1;;
esac

file_name="kubeedge-v"$kubeedge_version"-linux-"$kubeedge_arch".tar.gz"
dir_name="kubeedge-v"$kubeedge_version"-linux-"$kubeedge_arch
checksum_name="checksum_"$file_name".txt"
check_result=0

if [ ! -d "$KubeEdgePath" ]; then
    mkdir $KubeEdgePath
fi

if [ ! -d "$KubeEdgeConfPath" ]; then
    mkdir $KubeEdgeConfPath
fi

cd $KubeEdgePath

if [ "$downfile" == "false" ]; then
    if [ ! -e "$file_name" ] || [ ! -e "$checksum_name" ]; then
        echo "Error: $file_name or $checksum_name not existed in $KubeEdgePath!"
        exit -1
    else
	checksum=`sha512sum $file_name | awk '{print $1}'`
	rightsum=`cat $checksum_name`
	if [ $checksum == $rightsum ]; then
	    check_result=1
	    echo "check ok! start install edgecore..."
	else
	    echo "WARN: check failed, please re-download kubeedge tar."
	fi
    fi
else
    echo "Start download kubeedge tar..."
    for (( i=0; i<2; i=i+1 )); do
	rm -f $file_name
	rm -f $checksum_name
	wget --no-check-certificate $KubeEdgeDownloadURL"v"$kubeedge_version"/"$file_name
	wget --no-check-certificate $KubeEdgeDownloadURL"v"$kubeedge_version"/"$checksum_name
	
        if [ -e "$file_name" ] || [ -e "$checksum_name" ]; then
	    checksum=`sha512sum $file_name | awk '{print $1}'`
	    rightsum=`cat $checksum_name`
	    if [ $checksum == $rightsum ]; then
		check_result=1
		echo "check ok! start install edgecore..."
		break
	    else
		if [ $i -eq 0 ]; then
		    echo "WARN: check failed, re-download kubeedge tar..."
		    continue
		else
		    echo "WARN: check failed again, please check your network "\
		         "or origin file validity in $KubeEdgeDownloadURL."
		    exit -1
		fi
	    fi
	fi
    done
fi

ip_info=(${cloudcore_ipport//:/ })
cert_ipport="https:\/\/"${ip_info[0]}":"$cert_port

if [ $check_result -eq 1 ]; then
    tar -xvzf $file_name
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
systemctl start edgecore
systemctl enable edgecore