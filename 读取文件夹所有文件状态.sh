#!/bin/sh
#echo $#
if (( $# > 1)) || (( $# < 1 ))
then 
    echo "参数不正确，只需输入一个参数" 
elif [ -d "$1" ]
then
    echo "$1是一个目录,里面含以下文件:"
    for file in $(ls $1)
    do
	echo "$file is a " $(stat -c %F $1)

	echo "索引节点号:" $(stat -c %i $1)
	echo "文件大小:" $(stat -c %s $1) "B"
	echo "最近修改时间:" $(stat -c %y $1)
	echo ""
    done
elif [ -f "$1" ]
then 
	echo "$1 is a " $(stat -c %F $1)
	inode=$(stat -c %i $1)
	size=$(stat -c %s $1)
	lastModifyTime=$(stat -c %y $1)
	echo "索引节点号:" $inode
	echo "文件大小:" $size "B"
	echo "最近修改时间:" $lastModifyTime
fi
