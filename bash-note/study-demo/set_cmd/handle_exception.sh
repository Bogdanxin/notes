#!/bin/bash

# if there some command have problems, stop running
# use || to handle the exception
# bb || { echo "command not found"; exit 1; }


# use set -e, if have exception stop running
#set -e
#bb 

# we can also use set -e and set +e
cd f
set -e
tt
set +e
bb
