#!/bin/sh

#定义数组
array1=(1 2 3 4 5)
array2=(2 1 3 4 5)

#输入数组元素
echo "请依次第一个数组的5个元素(以回车分隔):"
for((i=0;i<5;i++))
do
	read x;
	array1[${i}]=$x
done

#输入数组元素
echo "请依次第二个数组的5个元素(以回车分隔):"
for((i=0;i<5;i++))
do
	read x;
	array2[${i}]=$x
done

echo "第一个数组的元素为：" ${array1[*]}
echo "第二个数组的元素为：" ${array2[*]}

#求数组欧式距离的平方
dist=0 
for((i=0;i<5;i++))
do
   tmp=1
   #dist=$[$dist + $tmp]
   tmp=$(bc << EOF
   scale = 4
   a = ( ${array1[$i]} - ${array2[$i]} )
   a * a
EOF
    )
   dist=$[$dist + $tmp]
done

#开平方，得到欧式距离
dist=$(bc << EOF
scale = 4
a = sqrt($dist)
a
EOF
)
echo "这两个数组之间的欧氏距离为：" $dist
