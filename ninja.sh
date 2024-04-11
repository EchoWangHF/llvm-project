#!/bin/bash
set -e

WORKSPACE="$(git rev-parse --show-toplevel)"
MLIR_VERSION_INFO="$(cat ${WORKSPACE}/VERSION)"
LLVM_BUILD_DIR="${WORKSPACE}/build"
LLVM_BUILD_TYPE="Release"
LLVM_SUB_PROJECTS="clang;mlir;compiler-rt"
LLVM_TARGETS_TO_BUILD="host;MLISA;NVPTX"
INSTALL_PREFIX_LLVM_MM="/usr/local/neuware/lib/llvm-xla"
INSTALL_PREFIX_LLVM_MM_CXX11_OLD_ABI="/usr/local/neuware/lib/llvm-xla-cxx11-old-abi"
INSTALL_PREFIX_LLVM_MM_CXX11_NEW_ABI="/usr/local/neuware/lib/llvm-xla"
LLVM_BUILD_PARALLEL_THREAD=32  # default need host 32 threads to build and test

export PATH=/usr/lib/ccache:$PATH
export SCCACHE_REDIS=redis://10.100.99.14:31379
export SCCACHE_LAUNCHER=$(which sccache)
# The docker(yellow.hub.cambricon.com/tensorflow/base/x86_64/pytorch-xla:latest-x86_64-ubuntu18.04-py3) image's default CC and CXX is clang, but we need gcc.
unset CC CXX CFLAGS CXXFLAGS _GLIBCXX_USE_CXX11_ABI

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


#########################################################################
# entry: parse the options                                              #
#########################################################################
if [ $# != 0 ]; then
  while [ $# != 0 ]; do
    case "$1" in
      -d | --debug)
        LLVM_BUILD_TYPE="debug"
        echo "[INFO] : build in ${LLVM_BUILD_TYPE} mode"
        shift
        ;;
      -c | --coverage)
        LLVM_MM_ENABLE_COVERAGE_TEST=ON
        echo "[INFO] : enabled coverage test"
        shift
        ;;
      -j*)
        THREAD=$1
        LLVM_BUILD_PARALLEL_THREAD=${THREAD#*-j}
        echo "[INFO] : build with parallel thread ${LLVM_BUILD_PARALLEL_THREAD}"
        shift
        ;;
      --disable_sccache)
        SCCACHE_LAUNCHER=""
        echo "[INFO] : sccache is disabled"
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

CONFIG="-S llvm -B ${LLVM_BUILD_DIR} \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
        -DCMAKE_C_COMPILER_LAUNCHER="$(which ccache)" \
        -DCMAKE_CXX_COMPILER_LAUNCHER="$(which ccache)" \
        -DLLVM_MLISA_RELEASE_FULL_FEATURE=ON \
        -DNEUWARE_HOME=${NEUWARE_HOME} \
        -DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD} \
        -DLLVM_ENABLE_PROJECTS=${LLVM_SUB_PROJECTS} \
        -DLLVM_BUILD_WITH_GENERIC_MTUNE=ON \
        -DLLVM_VERSION_SUFFIX= \
        -DLLVM_INSTALL_BINUTILS_SYMLINKS=OFF \
        -DLLVM_INSTALL_CCTOOLS_SYMLINKS=OFF \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_ENABLE_DOXYGEN=OFF \
        -DLLVM_ENABLE_SPHINX=OFF \
        -DLLVM_ENABLE_OCAMLDOC=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=ON \
        -DLLVM_LINK_LLVM_DYLIB=ON \
        -DLLVM_BUILD_TOOLS=ON \
        -DLLVM_INCLUDE_TOOLS=ON \
        -DLLVM_BUILD_UTILS=ON \
        -DLLVM_INCLUDE_UTILS=ON \
        -DLLVM_INSTALL_UTILS=ON \
        -DLLVM_BUILD_DOCS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_BUILD_RUNTIMES=OFF \
        -DLLVM_INCLUDE_RUNTIMES=OFF \
        -DLLVM_BUILD_EXAMPLES=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_APPEND_VC_REV=OFF \
        -DLLVM_ENABLE_BINDINGS=OFF \
        -DLLVM_USE_LINKER=gold \
        -DLLVM_BUILD_WITH_CODE_COVERAGE_TEST=${LLVM_MM_ENABLE_COVERAGE_TEST} \
        -DMLIR_VERSION=${MLIR_VERSION_INFO} \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX_LLVM_MM_CXX11_OLD_ABI} \
        -DLLVM_BUILD_WITH_OLD_GLIBCXX_ABI=ON"

# Prepare neuware.
if [ -z ${NEUWARE_HOME} ]; then
  export NEUWARE_HOME="${PWD}/neuware"
fi
if [ ! -d ${NEUWARE_HOME}/include ]; then
  echo "[ERROR] : Current NEUWARE_HOME is ${NEUWARE_HOME}, expected ${NEUWARE_HOME}/include directory."
  exit -1
fi
#########################################################################
# entry: config and build                                               #
#########################################################################
if [ -z "${SCCACHE_LAUNCHER}" ]; then
  echo "[WARN] Unable to find sccache..."
else
  # Report sccache stats for easier debugging
  sccache --zero-stats
fi
[ ! -d "${LLVM_BUILD_DIR}" ] && mkdir ${LLVM_BUILD_DIR}

cmake ${CONFIG}
ninja -C ${LLVM_BUILD_DIR} -j${LLVM_BUILD_PARALLEL_THREAD}

if [ ${LLVM_BUILD_TYPE} == "Release" ]; then
  strip ${LLVM_BUILD_DIR}/bin/mlir-mlu-compiler -g -S -d --strip-debug --strip-dw --strip-unneeded -s
  strip ${LLVM_BUILD_DIR}/bin/mlir-cnapi-compilert -g -S -d --strip-debug --strip-dw --strip-unneeded -s
fi

if [ ! -z "${SCCACHE_LAUNCHER}" ]; then
  sccache --show-stats
fi
