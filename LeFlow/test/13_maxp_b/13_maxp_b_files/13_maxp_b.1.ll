; ModuleID = '13_maxp_b.1.bc'
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux_gnu"

@temp0 = internal global [1 x [10 x [10 x [1 x float]]]] zeroinitializer, align 8
@param0 = internal global [1 x [32 x [32 x [1 x float]]]] zeroinitializer, align 8

; Function Attrs: nounwind
define float @main() #0 {
reduce-window.loop_body.dim.1.lr.ph:
  br label %reduce-window.loop_body.dim.2.lr.ph

reduce-window.loop_body.dim.2.lr.ph:              ; preds = %reduce-window.loop_exit.dim.2, %reduce-window.loop_body.dim.1.lr.ph
  %reduce-window.indvar.dim.130 = phi i64 [ 0, %reduce-window.loop_body.dim.1.lr.ph ], [ %14, %reduce-window.loop_exit.dim.2 ]
  %0 = mul i64 %reduce-window.indvar.dim.130, 3
  br label %reduce-window.inner.loop_body.window.1.lr.ph

reduce-window.inner.loop_body.window.1.lr.ph:     ; preds = %reduce-window.loop_exit.dim.3, %reduce-window.loop_body.dim.2.lr.ph
  %reduce-window.indvar.dim.227 = phi i64 [ 0, %reduce-window.loop_body.dim.2.lr.ph ], [ %13, %reduce-window.loop_exit.dim.3 ]
  %scevgep5 = getelementptr [1 x [10 x [10 x [1 x float]]]]* @temp0, i64 0, i64 0, i64 %reduce-window.indvar.dim.130, i64 %reduce-window.indvar.dim.227, i64 0
  %1 = mul i64 %reduce-window.indvar.dim.227, 3
  br label %reduce-window.inner.loop_body.window.3.lr.ph.us.preheader

reduce-window.inner.loop_body.window.3.lr.ph.us.preheader: ; preds = %reduce-window.inner.loop_exit.window.2, %reduce-window.inner.loop_body.window.1.lr.ph
  %2 = phi float [ 0xFFF0000000000000, %reduce-window.inner.loop_body.window.1.lr.ph ], [ %.lcssa, %reduce-window.inner.loop_exit.window.2 ]
  %reduce-window.inner.indvar.window.119 = phi i64 [ 0, %reduce-window.inner.loop_body.window.1.lr.ph ], [ %12, %reduce-window.inner.loop_exit.window.2 ]
  %3 = add i64 %0, %reduce-window.inner.indvar.window.119
  br label %reduce-window.inner.loop_exit.window.3.us

reduce-window.inner.loop_exit.window.3.us:        ; preds = %reduce-window.inner.loop_exit.window.3.us, %reduce-window.inner.loop_body.window.3.lr.ph.us.preheader
  %4 = phi float [ %10, %reduce-window.inner.loop_exit.window.3.us ], [ %2, %reduce-window.inner.loop_body.window.3.lr.ph.us.preheader ]
  %reduce-window.inner.indvar.window.24.us = phi i64 [ %11, %reduce-window.inner.loop_exit.window.3.us ], [ 0, %reduce-window.inner.loop_body.window.3.lr.ph.us.preheader ]
  %5 = add i64 %1, %reduce-window.inner.indvar.window.24.us
  %scevgep = getelementptr [1 x [32 x [32 x [1 x float]]]]* @param0, i64 0, i64 0, i64 %3, i64 %5, i64 0
  %6 = load volatile float* %scevgep, align 4
  %7 = fcmp oge float %4, %6
  %8 = fcmp ueq float %4, 0.000000e+00
  %9 = or i1 %7, %8
  %10 = select i1 %9, float %4, float %6
  %11 = add nuw nsw i64 %reduce-window.inner.indvar.window.24.us, 1
  %exitcond1 = icmp eq i64 %11, 3
  br i1 %exitcond1, label %reduce-window.inner.loop_exit.window.2, label %reduce-window.inner.loop_exit.window.3.us, !llvm.loop !1

reduce-window.inner.loop_exit.window.2:           ; preds = %reduce-window.inner.loop_exit.window.3.us
  %.lcssa = phi float [ %10, %reduce-window.inner.loop_exit.window.3.us ]
  %12 = add nuw nsw i64 %reduce-window.inner.indvar.window.119, 1
  %exitcond = icmp eq i64 %12, 3
  br i1 %exitcond, label %reduce-window.loop_exit.dim.3, label %reduce-window.inner.loop_body.window.3.lr.ph.us.preheader, !llvm.loop !3

reduce-window.loop_exit.dim.3:                    ; preds = %reduce-window.inner.loop_exit.window.2
  %.lcssa.lcssa = phi float [ %.lcssa, %reduce-window.inner.loop_exit.window.2 ]
  store volatile float %.lcssa.lcssa, float* %scevgep5, align 4
  %13 = add nuw nsw i64 %reduce-window.indvar.dim.227, 1
  %exitcond3 = icmp eq i64 %13, 10
  br i1 %exitcond3, label %reduce-window.loop_exit.dim.2, label %reduce-window.inner.loop_body.window.1.lr.ph, !llvm.loop !4

reduce-window.loop_exit.dim.2:                    ; preds = %reduce-window.loop_exit.dim.3
  %14 = add nuw nsw i64 %reduce-window.indvar.dim.130, 1
  %exitcond6 = icmp eq i64 %14, 10
  br i1 %exitcond6, label %reduce-window.loop_exit.dim.0, label %reduce-window.loop_body.dim.2.lr.ph, !llvm.loop !5

reduce-window.loop_exit.dim.0:                    ; preds = %reduce-window.loop_exit.dim.2
  %leflow_retval = load volatile float* getelementptr inbounds ([1 x [10 x [10 x [1 x float]]]]* @temp0, i64 0, i64 0, i64 0, i64 0, i64 0), align 8
  ret float %leflow_retval
}

attributes #0 = { nounwind "no-frame-pointer-elim"="false" }

!llvm.ident = !{!0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0}

!0 = metadata !{metadata !"clang version 3.5.0 (tags/RELEASE_350/final)"}
!1 = metadata !{metadata !1, metadata !2}
!2 = metadata !{metadata !"llvm.loop.vectorize.enable", i1 false}
!3 = metadata !{metadata !3, metadata !2}
!4 = metadata !{metadata !4, metadata !2}
!5 = metadata !{metadata !5, metadata !2}