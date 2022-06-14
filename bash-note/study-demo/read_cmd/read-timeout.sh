#!/bin/bash

echo -n "input something > "
if read -t 3 response; then
	echo "user input is $response"
else
	echo "user has no input"
fi
