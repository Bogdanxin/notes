#!/bin/bash

INT=-5

if [ -z "$INT" ]; then
	echo "empyt num." >&2
	exit 1
fi

if [ $INT ]
