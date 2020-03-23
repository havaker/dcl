#!/bin/sh

cat $XDG_RUNTIME_DIR/dcl-in | xargs --arg-file=$2 $1 > $XDG_RUNTIME_DIR/dcl-out
