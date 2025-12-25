#!/bin/bash
set -e

# Build script for mquickjs shared library
# This script checks out mquickjs to /tmp and builds it as a shared library

MQUICKJS_DIR="/tmp/mquickjs"
LIB_DIR="$(dirname "$0")/lib/mquickjs/ffi"

echo "Building mquickjs shared library..."

cd "$MQUICKJS_DIR"

# Build the stdlib generator first
echo "Building stdlib..."
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -O2 -c -o mqjs_stdlib.host.o mqjs_stdlib.c
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -O2 -c -o mquickjs_build.host.o mquickjs_build.c
gcc -g -o mqjs_stdlib mqjs_stdlib.host.o mquickjs_build.host.o
./mqjs_stdlib > mqjs_stdlib.h
./mqjs_stdlib -a > mquickjs_atom.h

# Compile object files with -fPIC for shared library
echo "Compiling object files..."
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -Os -fPIC -c -o mquickjs.o mquickjs.c
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -Os -fPIC -c -o dtoa.o dtoa.c
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -Os -fPIC -c -o libm.o libm.c
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -Os -fPIC -c -o cutils.o cutils.c

# Compile the wrapper
echo "Compiling wrapper..."
gcc -Wall -g -MMD -D_GNU_SOURCE -fno-math-errno -fno-trapping-math -Os -fPIC -c -o mquickjs_wrapper.o mquickjs_wrapper.c

# Create shared library
echo "Creating shared library..."
gcc -shared -o libmquickjs.so mquickjs.o dtoa.o libm.o cutils.o mquickjs_wrapper.o -lm

# Copy to lib directory
echo "Copying library to $LIB_DIR..."
mkdir -p "$LIB_DIR"
cp libmquickjs.so "$LIB_DIR/"
cp mquickjs.h "$LIB_DIR/"
cp mquickjs_wrapper.h "$LIB_DIR/"

echo "Build complete! Library: $LIB_DIR/libmquickjs.so"
