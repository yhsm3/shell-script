#!/bin/sh

read -p "输入区间" l r
sum=0
for((i=$l; i<=$r; i=i+2))
do
	let "sum += i"
done
echo "sum = " $sum

