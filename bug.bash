#!/bin/bash
set -e
echo "test"
k="kkkk"
read -p "asas: " name
query(){
    while [[ $choose != "y" && $choose != "n" ]]
    do
        read  -r -p $1 choose
    done
    echo $choose
}

echo $?
# k=$(query "aaa[y/n]:")
k=12
echo $k

if [ $(echo 19.03 19.03.8 | awk '{print($1>=$2)?1:0}') -eq 1 ]
then
    echo ">="
else 
    echo "<"    
fi