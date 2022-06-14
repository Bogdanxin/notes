#!/bin/bash
# set -x: print command before running
# like +echo bar

set -x
echo bar


# also can controller which command can be run
set -x
echo "set -x inside"
set +x

echo "set -x outside"
