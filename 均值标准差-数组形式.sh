#!/bin/bash
declare -a s #定义数组
read -p "输入数据: " -a s #读入数组
sum=0
b=1
size=${#s[*]} #获取数组长度
echo "len:" $size

#${s[*]}将数组元素表示成列表形式
for item in ${s[*]}
do
	let sum=sum+item
done
ave=`echo "scale=4;$sum/$size" | bc`
echo "均值：" $ave

ans=0
tmp=0;
for itme in ${s[*]}
do
	tmp=`echo "scale=4;$ave-$item" | bc`
	echo "tmp1 : " $tmp
	tmp=`echo "scale=4;$tmp*$tmp" | bc`
	echo "tmp2 : " $tmp
	ans=`echo "scale=4;$ans+$tmp" | bc`	
	echo "ans : " $ans
done
ans=`echo "scale=4;$ans/$size" | bc`
echo "开平方之前" $ans
ans=`echo "scale=4;sqrt($ans)" | bc`
echo "标准差" $ans
