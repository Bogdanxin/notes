#!/bin/bash

for i in *.sh; do
	echo "$i"
	cat $i
	echo ""
done
