; ModuleID = '02_vecmul_b.prelto.linked.bc'
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux_gnu"

@temp0 = global [64 x float] zeroinitializer, align 8
@param1 = global [64 x float] zeroinitializer, align 8
@param0 = global [64 x float] zeroinitializer, align 8

define float @main() #0 {
multiply.loop_body.dim.0.lr.ph:
  br label %multiply.loop_body.dim.0

multiply.loop_body.dim.0:                         ; preds = %multiply.loop_body.dim.0, %multiply.loop_body.dim.0.lr.ph
  %multiply.indvar.dim.02 = phi i64 [ 0, %multiply.loop_body.dim.0.lr.ph ], [ %invar.inc, %multiply.loop_body.dim.0 ]
  %0 = getelementptr inbounds [64 x float]* @param1, i64 0, i64 %multiply.indvar.dim.02
  %1 = load volatile float* %0, align 4
  %2 = getelementptr inbounds [64 x float]* @param0, i64 0, i64 %multiply.indvar.dim.02
  %3 = load volatile float* %2, align 4
  %4 = fmul float %1, %3
  %5 = getelementptr inbounds [64 x float]* @temp0, i64 0, i64 %multiply.indvar.dim.02
  store volatile float %4, float* %5, align 4
  %invar.inc = add nuw nsw i64 %multiply.indvar.dim.02, 1
  %6 = icmp ugt i64 %invar.inc, 63
  br i1 %6, label %multiply.loop_exit.dim.0, label %multiply.loop_body.dim.0, !llvm.loop !0

multiply.loop_exit.dim.0:                         ; preds = %multiply.loop_body.dim.0
  %leflow_gep = getelementptr inbounds [64 x float]* @temp0, i64 0, i64 0
  %leflow_retval = load volatile float* %leflow_gep, align 4
  ret float %leflow_retval
}

attributes #0 = { "no-frame-pointer-elim"="false" }

!0 = metadata !{metadata !0, metadata !1}
!1 = metadata !{metadata !"llvm.loop.vectorize.enable", i1 false}
