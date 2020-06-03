#!/bin/bash
#定义声明数组，for遍历数组
declare -a a
read -a a
size=${#a[*]}
for((i=0;i<$size;i++))
do
	echo ${a[$i]}
done

