#!/bin/sh
#通过修改环境变量IFS(内部字段分隔符)，实现字符串法分割
#默认是空格，tab符，换行符
line="12 13 14 15"
oldIFS=$IFS #备份原始的环境变量
#IFS=" " #设置新的分割符
sum=0
for item in $line
do 
	let "sum = sum + item"
done
IFS=$oldIFS #恢复原始环境变量
echo $sum

