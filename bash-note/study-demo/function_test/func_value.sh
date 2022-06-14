#!/bin/bash

foo=10
echo "$foo"

fun() {
	echo "$foo"
	local foo=100
	echo "$foo"

}
fun
echo "$foo"
