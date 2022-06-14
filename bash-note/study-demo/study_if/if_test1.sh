#!/bin/bash

read -p "input 1~3 num > " character
if [ "$character" = "1" ]; then
	echo 1
elif [ "$character" = "2" ]; then
	echo 2
elif [ "$character" = "3" ]; then
	echo 3
else 
	echo "error!"
fi
