#!/bin/bash

make
while true
do
    sh/benchmark.sh ./dcl-c tests/_test_0_2.key $1
    cp $XDG_RUNTIME_DIR/dcl-out $XDG_RUNTIME_DIR/dcl-outc
    sh/benchmark.sh ./dcl tests/_test_0_2.key

    if ! diff -q $XDG_RUNTIME_DIR/dcl-outc $XDG_RUNTIME_DIR/dcl-out &>/dev/null; then
        >&2 echo "different"
        cp $XDG_RUNTIME_DIR/dcl-out out-asm
        cp $XDG_RUNTIME_DIR/dcl-outc out-c
        exit 1
    fi
done

