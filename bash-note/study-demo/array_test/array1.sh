#!/bin/bash

name=(a,b,c,d,e)
for i in "$(name[@])"; do
	echo $i
done
