#!/bin/bash
set -e
WORKSPACE="$(git rev-parse --show-toplevel)"
LLVM_BUILD_DIR="${WORKSPACE}/build"
LLVM_BUILD_PARALLEL_THREAD=4
LLVM_BUILD_TYPE="Release"
LLVM_SUB_PROJECTS="mlir"
LLVM_TARGETS_TO_BUILD="host;NVPTX"
LLVM_SET_ASAN="Address;Undefined"

#########################################################################
# func: usage helper                                                    #
#########################################################################
usage () {
  echo "USAGE: build.sh [Options]"
  echo ""
  echo "       This script build llvm-project with cambricon configration."
  echo ""
  echo "Options:"
  echo "      NULL                Default build enabled submodules in release mode"
  echo "      -h, --help          Print usage"
  echo "      -jN                 Used to contol make -jN and make test -jN"
  echo "      -d, --debug         Enable build in debug mode"
  echo "      -c, --coverage      Enable coverage test"
}


if [ $# != 0 ]; then
  while [ $# != 0 ]; do
    case "$1" in
      -d | --debug)
        LLVM_BUILD_TYPE="debug"
        echo "[INFO] : build in ${LLVM_BUILD_TYPE} mode"
        shift
        ;;
      -j*)
        THREAD=$1
        LLVM_BUILD_PARALLEL_THREAD=${THREAD#*-j}
        echo "[INFO] : build with parallel thread ${LLVM_BUILD_PARALLEL_THREAD}"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] : Unknown options ${1}"
        usage
        exit -1
        ;;
    esac
  done
fi

# Using clang and lld speeds up the build, we recommend adding:
#  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_LLD=ON
# CCache can drastically speed up further rebuilds, try adding:
#  -DLLVM_CCACHE_BUILD=ON
# Optionally, using ASAN/UBSAN can find bugs early in development, enable with:
# -DLLVM_USE_SANITIZER="Address;Undefined"
# Optionally, enabling integration tests as well
# -DMLIR_INCLUDE_INTEGRATION_TESTS=ON
CONFIG="-S llvm -B ${LLVM_BUILD_DIR} \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
        -DLLVM_ENABLE_PROJECTS=${LLVM_SUB_PROJECTS} \
        -DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD} \
        -DLLVM_USE_SANITIZER=${LLVM_SET_ASAN} \
        -DLLVM_BUILD_WITH_GENERIC_MTUNE=ON \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_BUILD_LLVM_DYLIB=ON \
        -DLLVM_LINK_LLVM_DYLIB=ON \
        -DLLVM_BUILD_TOOLS=ON \
        -DLLVM_INCLUDE_TOOLS=ON \
        -DLLVM_BUILD_UTILS=ON \
        -DLLVM_INCLUDE_UTILS=ON \
        -DLLVM_INSTALL_UTILS=ON \
        -DLLVM_BUILD_EXAMPLES=ON \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DLLVM_ENABLE_LLD=ON \
        -DMLIR_INCLUDE_INTEGRATION_TESTS=ON \
        -DLLVM_CCACHE_BUILD=ON
        "

[ ! -d "${LLVM_BUILD_DIR}" ] && mkdir ${LLVM_BUILD_DIR}

cmake ${CONFIG}
ninja -C ${LLVM_BUILD_DIR} -j${LLVM_BUILD_PARALLEL_THREAD}
