#!/bin/bash
#--------------------------------------------------------------------------
# Program     : spmake
# Version     : v1.0
# Description : Tool to compile sourcemod plugin scripts.
# Syntax      : spmake.sh <script.sp>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

#set -x

smx_dir=$PWD/../plugins
smx_bin=$PWD/spcomp

if [[ $# -ne 0 ]]
then
    for i in "$@";
    do
        smxfile="`echo $i | sed -e 's/\.sp$/\.smx/'`";
        echo -n "Compiling $i...";
        $smx_bin $i -o $smx_dir/$smxfile
    done
else
    echo "No sourcefile given."
fi
