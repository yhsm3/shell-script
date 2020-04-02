#!/bin/sh
cd ~
mkdir shell_out
cd shell_out
for((i=0; i<10; i++))
do
    touch test_${i}.txt
done

