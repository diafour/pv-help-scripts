#!/usr/bin/env bash
# cpv is a helper for copy files with pipe-viewer (pv) progress monitor
# 
# Copyright 2016 diafour
# Source: http://github.com/diafour/pv-help-scripts
# This script is licensed under GPLv3; see LICENSE for details.
# 


# Print usage and exit
function usage()
{
    cat <<END_USAGE
Usage: `basename $0` SOURCE DEST
       `basename $0` SOURCE DIRECTORY
       `basename $0` SOURCE... DIRECTORY
Copy SOURCE file to DEST file or DEST directory, or multiple SOURCEs to DEST directory
with progress monitoring.

END_USAGE

    exit
}

PVCMD="`which pv`"
#$PVCMD > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
    echo "Error: pv not installed or not in PATH"
    echo
    usage
fi

[ $# -lt 2 ] && usage

# DESTINATION
# Last parameter is destination like with cp command.
dest="${!#}"

# SOURCE is all other parameters
# Array of all parameters except last. Array used for proper handle of spaces in filenames.
src=("${@:1:($#-1)}")
# Calculate size of all sources
size=$(du -sbc "${src[@]}" | tail -n 1 | awk '{print $1}')

PVCMD="$PVCMD -s $size $PVOPTS"


if [[ $# -eq 2 && -d "${src[0]}" && -f "$dest" ]]
then
    echo "Error: Copy SOURCE directory to DEST file is not supported"
    echo
    usage
fi

if [[ $# -eq 2 && -f "${src[0]}"  && ( -f "$dest" || ! -e "$dest" ) ]]
then
    # Copy SOURCE file to DEST file probably with new name
    # cat is simpler than tar here
    cat "${src[0]}" | $PVCMD > "${dest}"

elif [ -d "$dest" ]
then
    # cp copy many source files without their pathes. Tar can do this with striping path from filenames using --xfrom/--transform.
    # It works only for files. If src has directories then dest will be messed.
    # tar --xform='s,.*/,,' --show-transformed -v -c -f ar.tar ../../test/a/1.png ../../test/a/aa/ad.jpg 1.png a
    # tar -C dirname cf - basename - this works for directories.
    # So loop over params and send tars to one pipe and untar with --ignore-zeros
    {        
    for i in "${src[@]}"; do
        if [ -f "$i" ]
        then
            tar --xform='s,.*/,,' -c -f - "$i" 2>/dev/null
        fi
        if [ -d "$i" ]
        then
            srcdir=`dirname "$i"`
            srcname=`basename "$i"`
            tar -C "$srcdir" -c -f - "$srcname"
        fi
    done
    } | $PVCMD | tar --ignore-zeros -C "$dest" -x -f - 
else
    usage
fi
 
