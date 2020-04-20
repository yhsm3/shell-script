#!/bin/sh
read -p "请输入N（N>0）:" N

#判断输入是否合法
if (( N <= 0 )) || echo $N | grep -q '[^0-9]' #通过grep去筛选非数字，判断其输出状态
then
    echo "输入不合法,请输入一个大于0的数字"
    exit  #输入不正确，直接退出
fi

ans=0
for((i=1;i<=N;i++))
do
    ans=$(bc << EOF
    scale = 3
    a = 1 / $i
    a + $ans
EOF
    )
done
echo $ans
