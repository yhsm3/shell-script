#!/bin/sh
#shell默认不支持浮点运算，需要使用bc语言进行浮点运算
read -p "请输入若干个整数（回车结束输入）" score
sum=0
count=0;
for item in $score
do 
	let count=count+1
	let sum=sum+item
done

#echo $sum 
#echo $count

average=$(echo "scale=4; $sum / $count" | bc) 

#echo $average

answer=0
for item in $score
do 
#	echo $item
	answer=$(bc	<< EOF
	scale = 4
	a = ( $item - $average ) 
	b = a * a
	b + $answer
EOF
	)
done

answer=$(bc << EOF
scale=4
a = $answer / $count
a = sqrt(a)
a
EOF
)
printf "总和：%d\n个数：%d\n" $sum $count
printf "均值：%.2f\n标准差：%.2f\n" $average $answer
