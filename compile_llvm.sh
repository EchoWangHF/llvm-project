#bash build llvm
rm -rf build_llvm
mkdir build_llvm
cd build_llvm

#cmake -G <generator> -DCMAKE_BUILD_TYPE=<type> [options] ../llvm
#1. Some common build system <generators> are:
#  Ninja — for generating Ninja build files. Most llvm developers use Ninja.
#  Unix Makefiles — for generating make-compatible parallel makefiles.
#  Visual Studio — for generating Visual Studio projects and solutions.
#  Xcode — for generating Xcode projects.
#
#2. Some Common [options]:
#   -DLLVM_ENABLE_PROJECTS='...' — semicolon-separated list of the LLVM subprojects you’d like to additionally build. Can include any of: clang, clang-tools-extra, lldb, compiler-rt, lld, polly, or cross-project-tests.
#    For example, to build LLVM, Clang, libcxx, and libcxxabi, use -DLLVM_ENABLE_PROJECTS="clang" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi".
#   -DCMAKE_INSTALL_PREFIX=directory — Specify for directory the full pathname of where you want the LLVM tools and libraries to be installed (default /usr/local).
#   -DCMAKE_BUILD_TYPE=type — Controls optimization level and debug information of the build. The default value is Debug which fits people who want to work on LLVM or its libraries. Release is a better fit for most users of LLVM and Clang. For more detailed information see CMAKE_BUILD_TYPE.
#   -DLLVM_ENABLE_ASSERTIONS=On — Compile with assertion checks enabled (default is Yes for Debug builds, No for all other build types).

#cmake --build . [--target <target>] or the build system specified above directly.
#  The default target (i.e. cmake --build . or make) will build all of LLVM
#  The check-all target (i.e. ninja check-all) will run the regression tests to ensure everything is in working order.
#  CMake will generate build targets for each tool and library, and most LLVM sub-projects generate their own check-<project> target.
#  Running a serial build will be slow. To improve speed, try running a parallel build. That’s done by default in Ninja; for make, use the option -j NN, where NN is the number of parallel jobs, e.g. the number of available CPUs.

#cmake -G "Unix Makefiles" -DLLVM_TARGETS_TO_BUILD=X86 -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_PREFIX=${PWD}/../neuware/ ../llvm
cmake -G "Unix Makefiles" -DLLVM_TARGETS_TO_BUILD=X86 -DCMAKE_BUILD_TYPE="Release" ../llvm

make -j32
#make install
