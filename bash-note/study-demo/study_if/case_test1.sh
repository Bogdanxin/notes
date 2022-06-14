#!/bin/bash

read -p "input a number between 1 and 3 > " c
case $c in
	1) echo 1
		;;
	2) echo 2
		;;
	3) echo 3
		;;
	*) echo "error!"
esac
