#!/bin/bash

if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "usage:"
    echo "    $0 executable parameters.key"
    exit 1
fi

if [ "$3" == "" ]; then
    echo "no generating"
else
    SIZE="$3"
    echo "generating $SIZE"
    ./generate $SIZE > $XDG_RUNTIME_DIR/dcl-in
    test $? -eq 0 || exit 1
fi


{ time -p sh/run.sh $1 $2; } 2>&1 | grep real | grep -o '[0-9.]*'
