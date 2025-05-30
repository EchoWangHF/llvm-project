; RUN: llc < %s -O0 -mtriple=nvptx64 -mcpu=sm_20 | FileCheck %s
; RUN: %if ptxas %{ llc < %s -O0 -mtriple=nvptx64 -mcpu=sm_20 | %ptxas-verify %}

; CHECK-LABEL: .visible .func (.param .align 16 .b8 func_retval0[16]) callee(
define i128 @callee(i128) {
  ; CHECK: ld.param.v2.u64 {%[[REG0:rd[0-9]+]], %[[REG1:rd[0-9]+]]}, [callee_param_0];
  ; CHECK: st.param.v2.b64 [func_retval0], {%[[REG0]], %[[REG1]]}
  ret i128 %0
}

; CHECK-LABEL: .visible .func caller(
define void @caller(i128, ptr) {
start:
  ; CHECK-DAG: ld.param.v2.u64 {%[[REG0:rd[0-9]+]], %[[REG1:rd[0-9]+]]}, [caller_param_0];
  ; CHECK-DAG: ld.param.u64 %[[OUT:rd[0-9]+]],  [caller_param_1];

  ; CHECK: { // callseq 0, 0
	; CHECK: .param .align 16 .b8 retval0[16];
	; CHECK: call.uni (retval0),
  ; CHECK: ld.param.v2.b64 {%[[REG2:rd[0-9]+]], %[[REG3:rd[0-9]+]]}, [retval0];
	; CHECK: } // callseq 0
  %a = call i128 @callee(i128 %0)

	; CHECK-DAG: st.v2.u64 [%[[OUT]]], {%[[REG2]], %[[REG3]]};
  store i128 %a, ptr %1

  ret void
}
