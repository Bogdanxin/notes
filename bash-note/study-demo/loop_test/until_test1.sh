#!/bin/bash

number=0
until  echo "number : $number" && [ "$number" -ge 10 ] ; do
	echo "number is $number"
	number=$((number+1))
done
