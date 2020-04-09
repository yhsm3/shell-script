#!/bin/sh
#进入回收站
cd ~/.local/share/Trash/files/
#获取回收站列表
for item in $(ls)
do 
	if [ -d $item ] #判断是否是目录
	then 
		rm -ir $item
		rm ../info/${item}.trashinfo #顺便删除文件的信息
	elif [ -f $item ]
	then 
		rm -i $item	
		rm ../info/${item}.trashinfo
	fi 
done


