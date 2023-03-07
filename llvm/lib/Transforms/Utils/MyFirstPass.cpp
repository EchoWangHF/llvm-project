//===-- MyFirstPass.cpp - Example Transformations -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Utils/MyFirstPass.h"

using namespace llvm;

PreservedAnalyses MyFirstPass::run(Function &F,
                                      FunctionAnalysisManager &AM) {
  errs() << F.getName() << "\n";
  errs() << "This is my first pass \n";
  return PreservedAnalyses::all();
}
