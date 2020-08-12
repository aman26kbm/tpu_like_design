; ModuleID = '15_thxprlsg.prelto.1.bc'
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux_gnu"

@temp0 = global [8 x float] zeroinitializer, align 8
@param0 = global [8 x float] zeroinitializer, align 8

define float @main() #0 {
fusion.loop_body.dim.0.lr.ph:
  br label %fusion.loop_body.dim.0

fusion.loop_body.dim.0:                           ; preds = %fusion.loop_body.dim.0, %fusion.loop_body.dim.0.lr.ph
  %fusion.indvar.dim.02 = phi i64 [ 0, %fusion.loop_body.dim.0.lr.ph ], [ %invar.inc, %fusion.loop_body.dim.0 ]
  %0 = getelementptr inbounds [8 x float]* @param0, i64 0, i64 %fusion.indvar.dim.02
  %1 = load volatile float* %0, align 4
  %2 = call float @tanhf(float %1)
  %3 = call float @llvm.exp.f32(float %2)
  %4 = fcmp ole float %3, 0.000000e+00
  %.op = fmul float %3, 5.000000e-01
  %5 = select i1 %4, float 0.000000e+00, float %.op
  %6 = call float @tanhf(float %5)
  %7 = fmul float %6, 5.000000e-01
  %8 = fadd float %7, 5.000000e-01
  %9 = getelementptr inbounds [8 x float]* @temp0, i64 0, i64 %fusion.indvar.dim.02
  store volatile float %8, float* %9, align 4
  %invar.inc = add nuw nsw i64 %fusion.indvar.dim.02, 1
  %10 = icmp ugt i64 %invar.inc, 7
  br i1 %10, label %fusion.loop_exit.dim.0, label %fusion.loop_body.dim.0, !llvm.loop !0

fusion.loop_exit.dim.0:                           ; preds = %fusion.loop_body.dim.0
  %leflow_gep = getelementptr inbounds [8 x float]* @temp0, i64 0, i64 0
  %leflow_retval = load volatile float* %leflow_gep, align 4
  ret float %leflow_retval
}

; Function Attrs: nounwind readnone
declare float @tanhf(float) #1

; Function Attrs: nounwind readnone
declare float @llvm.exp.f32(float) #1

attributes #0 = { "no-frame-pointer-elim"="false" }
attributes #1 = { nounwind readnone }

!0 = metadata !{metadata !0, metadata !1}
!1 = metadata !{metadata !"llvm.loop.vectorize.enable", i1 false}
